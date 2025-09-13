# cc_fraud_nn_openml_viz.py
# end to end: pull data, train a tiny nn, plot plain defaults, print takeaways
# zero theme tweaks, no fallbacks, just matplotlib defaults

import os, warnings, numpy as np, pandas as pd, openml, matplotlib.pyplot as plt, tensorflow as tf
warnings.filterwarnings("ignore")  # kill noisy warnings so the run reads clean

from tensorflow.keras import layers as l, models as m  # shorter handles
from sklearn.model_selection import train_test_split   # standard split
from sklearn.preprocessing import StandardScaler       # scale features
from sklearn.metrics import (                          # eval bits we actually use
    confusion_matrix, classification_report, roc_curve, roc_auc_score,
    precision_recall_curve, average_precision_score, brier_score_loss
)
from sklearn.calibration import calibration_curve
from sklearn.utils import class_weight                 # balance rare fraud class

# -- data ----------------------------------------------------------------------

def load_data():
    # pull public credit card fraud dataset (openml id: 42175)
    ds = openml.datasets.get_dataset(42175)
    df, *_ = ds.get_data()
    return df

def preprocess(df):
    # quick sanity: dataset should include 'Class' (0 legit, 1 fraud)
    assert "Class" in df.columns, "expected a 'Class' column in dataset"
    # split features/label; keep column case as-is (it's how the file ships)
    y = df["Class"].astype(int).values
    X = df.drop("Class", axis=1).values
    # standardize features (nn likes scaled inputs)
    X = StandardScaler().fit_transform(X)
    # stratify so the rare class distribution is preserved in train/test
    Xt, Xs, yt, ys = train_test_split(X, y, test_size=.2, random_state=42, stratify=y)
    return X, y, Xt, Xs, yt, ys

# -- model ---------------------------------------------------------------------

def build_model(d):
    # tiny dense baseline: good signal without getting fancy
    x = m.Sequential([
        l.Input(shape=(d,)),                # explicit Input layer ensures model.input exists
        l.Dense(64, activation="relu"),
        l.Dropout(.4),
        l.Dense(32, activation="relu"),
        l.Dropout(.4),
        l.Dense(1, activation="sigmoid")
    ])
    # standard binary setup; include precision/recall/auc for easy reads
    x.compile(
        optimizer="adam",
        loss="binary_crossentropy",
        metrics=["accuracy",
                 tf.keras.metrics.Precision(name="precision"),
                 tf.keras.metrics.Recall(name="recall"),
                 tf.keras.metrics.AUC(name="auc")]
    )
    return x

# -- threshold helper ----------------------------------------------------------

def best_threshold_by_f1(y, p):
    # sweep thresholds indirectly via pr curve; pick argmax f1
    P, R, T = precision_recall_curve(y, p)
    f = 2 * (P[:-1] * R[:-1]) / (P[:-1] + R[:-1] + 1e-12)
    i = np.nanargmax(f)
    return T[i], P[i], R[i], f[i]

# -- plots (matplotlib defaults only) ------------------------------------------

def plot_confusion(cm, save_to=None, title="confusion matrix (normalized)"):
    # normalize per row so the fractions read clean
    cmn = cm / cm.sum(axis=1, keepdims=True)
    plt.figure()  # use default size and default style
    plt.imshow(cmn)
    plt.title(title)
    plt.xticks([0, 1], ["pred legit", "pred fraud"])
    plt.yticks([0, 1], ["actual legit", "actual fraud"])
    # annotate cells with values
    for i in range(2):
        for j in range(2):
            plt.text(j, i, f"{cmn[i, j]:.2f}", ha="center", va="center")
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

def plot_roc_curve(y, p, save_to=None):
    # classic roc; diagonal as reference
    fpr, tpr, _ = roc_curve(y, p)
    auc = roc_auc_score(y, p)
    plt.figure()
    plt.plot(fpr, tpr, label=f"auc = {auc:.4f}")
    plt.plot([0, 1], [0, 1], "--")
    plt.xlabel("false positive rate")
    plt.ylabel("true positive rate")
    plt.title("roc curve (separation power)")
    plt.legend()
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

def plot_pr_curve(y, p, save_to=None):
    # precision vs recall is the money chart for rare events
    P, R, _ = precision_recall_curve(y, p)
    ap = average_precision_score(y, p)
    plt.figure()
    plt.plot(R, P, label=f"avg precision = {ap:.4f}")
    plt.xlabel("recall")
    plt.ylabel("precision")
    plt.title("precision–recall curve (rare-event focus)")
    plt.legend()
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

def plot_threshold_sweep(y, p, save_to=None):
    # visualize precision/recall trade-off across thresholds
    T = np.linspace(0, 1, 200)
    prec, rec = [], []
    for t in T:
        yp = (p >= t).astype(int)
        tp = ((yp == 1) & (y == 1)).sum()
        fp = ((yp == 1) & (y == 0)).sum()
        fn = ((yp == 0) & (y == 1)).sum()
        prec.append(tp / (tp + fp + 1e-12))
        rec.append(tp / (tp + fn + 1e-12))
    plt.figure()
    plt.plot(T, prec, label="precision")
    plt.plot(T, rec, label="recall")
    plt.xlabel("decision threshold")
    plt.ylabel("score")
    plt.title("threshold tuning (pick your trade-off)")
    plt.legend()
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

def plot_calibration(y, p, save_to=None):
    # reliability: predicted vs observed; diagonal is perfect
    pt, pp = calibration_curve(y, p, n_bins=15, strategy="quantile")
    b = brier_score_loss(y, p)
    plt.figure()
    plt.plot(pp, pt, label=f"brier = {b:.4f}")
    plt.plot([0, 1], [0, 1], "--")
    plt.xlabel("predicted probability")
    plt.ylabel("observed fraud rate")
    plt.title("reliability (calibration) curve")
    plt.legend()
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

def plot_risk_map_2d(X, y, p, save_to=None):
    # quick 2d map: umap for layout, color by risk, ring true frauds
    import umap  # assume installed; no tsne fallback by request
    emb = umap.UMAP(n_neighbors=30, min_dist=.15, random_state=42).fit_transform(X)
    pr = (p - p.min()) / (p.max() - p.min() + 1e-12)  # size by risk
    sz = 10 + 90 * pr
    plt.figure()
    sc = plt.scatter(emb[:, 0], emb[:, 1], c=p, s=sz, alpha=.65)
    i = np.where(y == 1)[0]
    plt.scatter(emb[i, 0], emb[i, 1], facecolors="none", s=120, label="actual fraud")
    c = plt.colorbar(sc)
    c.set_label("predicted fraud probability")
    plt.title("risk map (umap) — hot clusters = high risk")
    plt.legend()
    plt.tight_layout()
    (plt.savefig(save_to, dpi=150) if save_to else None)
    plt.show()

# -- main ----------------------------------------------------------------------

def main():
    # set seeds for repeat-ish results
    np.random.seed(42); tf.random.set_seed(42)

    # load + prep
    df = load_data()
    Xa, ya, Xt, Xs, yt, ys = preprocess(df)
    print(f"dataset size: {len(ya):,} | fraud rate: {100*ya.mean():.3f}%")

    # model + class weights (handle imbalance)
    model = build_model(Xt.shape[1])
    cw = class_weight.compute_class_weight(class_weight="balanced", classes=np.unique(yt), y=yt)
    cw = {0: cw[0], 1: cw[1]}
    print("class weights:", cw)

    # quick train; big batch is fine here
    model.fit(Xt, yt, validation_data=(Xs, ys), epochs=15, batch_size=2048, class_weight=cw, verbose=2)

    # eval at 0.5 and show core metrics
    p = model.predict(Xs, verbose=0).flatten()
    yhat = (p >= .5).astype(int)
    print("\nconfusion matrix (threshold = 0.50):")
    cm = confusion_matrix(ys, yhat); print(cm)
    print("\nclassification report (threshold = 0.50):")
    print(classification_report(ys, yhat, digits=4))
    auc = roc_auc_score(ys, p); ap = average_precision_score(ys, p)
    print(f"roc auc: {auc:.4f} | avg precision (pr-auc): {ap:.4f}")

    # suggest a starting threshold by f1 (then tune to budget)
    t, pp, rr, f1 = best_threshold_by_f1(ys, p)
    print(f"\nrecommended starting threshold by f1: {t:.3f} (precision={pp:.3f}, recall={rr:.3f}, f1={f1:.3f})")

    # dump figures to site assets directory (used by front-end)
    OUTPUT_DIR = "assets/img/cc-fraud"
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    paths = {
        "confusion": f"{OUTPUT_DIR}/confusion_matrix.png",
        "roc": f"{OUTPUT_DIR}/roc_curve.png",
        "pr": f"{OUTPUT_DIR}/precision_recall_curve.png",        # was pr_curve.png
        "threshold": f"{OUTPUT_DIR}/threshold_tuning.png",       # was threshold_sweep.png
        "calibration": f"{OUTPUT_DIR}/reliability_curve.png",    # was calibration.png
        "risk": f"{OUTPUT_DIR}/risk_map.png"
    }

    plot_confusion(cm, paths["confusion"])
    plot_roc_curve(ys, p, paths["roc"])
    plot_pr_curve(ys, p, paths["pr"])
    plot_threshold_sweep(ys, p, paths["threshold"])
    plot_calibration(ys, p, paths["calibration"])

    # risk map using penultimate (last hidden Dense) layer embeddings (nice structure)
    try:
        # ensure model is built (should be after fit, but safeguard)
        if not model.built:
            model.predict(Xt[:1], verbose=0)
        # find last hidden Dense layer (exclude final output layer)
        last_hidden_layer = None
        for layer in reversed(model.layers):
            if isinstance(layer, tf.keras.layers.Dense) and layer != model.layers[-1]:
                last_hidden_layer = layer
                break
        if last_hidden_layer is None:
            raise RuntimeError("No hidden Dense layer found for embeddings.")
        embed_model = tf.keras.Model(inputs=model.input, outputs=last_hidden_layer.output)
        Z = embed_model.predict(Xa, verbose=0)
    except Exception as e:
        print(f"embedding extraction failed ({e}); using scaled features instead.")
        Z = Xa
    pa = model.predict(Xa, verbose=0).flatten()
    plot_risk_map_2d(Z, ya, pa, paths["risk"])

    print("\nSaved evaluation artifacts:")
    for k,v in paths.items():
        print(f" - {k:11s}: {v}")

    # quick human notes to steer usage (print only, keep it simple)
    print("\n==== interpret these visuals ====")
    print("- roc curve: more top-left bend = better separation")
    print("- precision–recall: for rare fraud, balance recall vs analyst load")
    print("- threshold sweep: pick a point that matches chargeback vs ops cost")
    print("- calibration: diagonal-ish means probs are trustworthy")
    print("- confusion matrix: track caught vs missed; slice by merchant/device")
    print("- risk map: hot clusters hint at rings/devices to dig into")
    print("\n==== ops playbook ideas ====")
    print("- start at the f1 threshold, then adjust to hit alert budget")
    print("- auto/step-up high risk; queue medium; pass low with light checks")
    print("- watch drift; if auc or calibration dips, refresh training")
    print("- pair with rules/graphs (shared ip/device/merchant) to cut false hits")

if __name__ == "__main__":
    main()
