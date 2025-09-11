# ------------------------------------------------------------
# technical notes:
# - place this script in the same directory as the target pdf
# - specify the filename in the main block (default: "DGAI.pdf")
# - output will be generated as an svg file in the same directory
# - this script only converts the first page of the pdf
# ------------------------------------------------------------

import fitz  # pymupdf library...see git readme for install instructions
import os

def pdf_to_svg(pdf_file):
    # determine script location to ensure consistent path resolution
    script_dir = os.path.dirname(os.path.abspath(__file__))
    pdf_path = os.path.join(script_dir, pdf_file)
    output_file = os.path.splitext(pdf_path)[0] + ".svg"

    # open pdf and extract the first page
    doc = fitz.open(pdf_path)
    page = doc[0]  # zero-based index
    svg = page.get_svg_image()

    # write svg output with utf-8 encoding
    with open(output_file, "w", encoding="utf-8") as f:
        f.write(svg)

    # console confirmation
    print(f"converted: {output_file}")

if __name__ == "__main__":
    # default input file (modify as required)
    pdf_to_svg("DGAI.pdf")
