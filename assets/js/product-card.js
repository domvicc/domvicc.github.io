/* minimal helper to wire up the amazon link and image from data-* attributes */
(function () {
  var card = document.querySelector('.product-card');
  if (!card) return;

  var asin = (card.dataset.asin || '').trim();
  if (!asin) return;

  var title = card.dataset.title || '';
  var description = card.dataset.description || '';
  var tag = card.dataset.tag || '';               // optional affiliate tag, e.g., yourtag-20
  var imgSize = card.dataset.imgSize || '_SL500_'; // _SL500_, _SL300_, etc.

  var img = document.getElementById('product-image');
  var ttl = document.getElementById('product-title');
  var desc = document.getElementById('product-desc');
  var link = document.getElementById('product-link');
  var asinSpan = document.getElementById('product-asin');

  if (ttl) ttl.textContent = title || ('asin ' + asin);
  if (desc) desc.textContent = description || '';
  if (asinSpan) asinSpan.textContent = asin;

  var baseUrl = 'https://www.amazon.com/dp/' + encodeURIComponent(asin);
  var href = tag ? baseUrl + '?tag=' + encodeURIComponent(tag) : baseUrl;

  if (link) {
    link.href = href;
    link.setAttribute('aria-label', 'view ' + (title || 'product') + ' on amazon');
  }

  /* amazon asin image endpoint (works well for simple static previews).
     note: some ad blockers may block this domain; we add a graceful fallback. */
  if (img) {
    var imgUrl = 'https://ws-na.amazon-adsystem.com/widgets/q'
      + '?_encoding=UTF8'
      + '&ASIN=' + encodeURIComponent(asin)
      + '&Format=' + encodeURIComponent(imgSize)
      + '&ID=AsinImage'
      + '&MarketPlace=US'
      + '&ServiceVersion=20070822'
      + '&WS=1'
      + (tag ? '&tag=' + encodeURIComponent(tag) : '');

    img.src = imgUrl;

    img.onerror = function () {
      // if the ads image is blocked/unavailable, remove the img to avoid a broken thumbnail
      img.remove();
    };
  }
})();
