from pypdf import PdfReader
import re

departments_map = {}
with open("input_files/departments_map.txt") as file:
    for line in file:
        match = re.match(r"([A-Z]{4})\s*(.+)", line.strip())
        if match:
            departments_map[match.group(1)] = match.group(2)
print(departments_map)

# Open the PDF file in binary read mode
with open("input_files/catalogo.pdf", "rb") as pdf_file:  # TODO: update path
    pdf_reader = PdfReader(pdf_file)

    # Initialize an empty string to store the text
    pdf_text = ""

    # Loop through each page and extract the text
    for page in pdf_reader.pages:
        pdf_text += page.extract_text()

curriculums_map = {}
for code, name in departments_map.items():
    regex = (
        rf"({name}\s*CURRICULUM\s*(.*?)Total credits required for this program:\s*\d+)"
    )
    match = re.search(regex, pdf_text, re.DOTALL)
    if match:
        curriculums_map[code] = match.group(1)
print(curriculums_map)
# with open("curriculum_output.txt", "w", encoding="utf-8") as file:
#     file.write(pdf_text)
# print(pdf_text[:pdf_text.index("SOFTWARE ENGINEERING")+10000])
