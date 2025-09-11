import os
import cairosvg
from PyPDF2 import PdfReader

# function to convert pdf to svg
def convert_pdf_to_svg(input_dir, output_dir):
    # make sure output folder exists
    os.makedirs(output_dir, exist_ok=True)

    # loop through all pdf files in input folder
    for file in os.listdir(input_dir):
        if file.lower().endswith(".pdf"):
            pdf_path = os.path.join(input_dir, file)
            pdf_name = os.path.splitext(os.path.basename(pdf_path))[0]

            # read pdf to get page count
            reader = PdfReader(pdf_path)

            # loop through each page in pdf
            for i, _ in enumerate(reader.pages, start=1):
                output_svg = os.path.join(output_dir, f"{pdf_name}_page_{i}.svg")
                # convert page to svg
                cairosvg.pdf2svg(
                    url=pdf_path,
                    write_to=output_svg,
                    page=i
                )
                print(f"saved: {output_svg}")

# example usage
if __name__ == "__main__":
    # set these paths as needed for your project
    input_dir = r"C:\path\to\pdfs"
    output_dir = r"C:\path\to\svgs"

    convert_pdf_to_svg(input_dir, output_dir)
