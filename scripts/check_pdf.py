import pdfplumber

with pdfplumber.open('E:/originalam/reports/go-On_Character_Animation_Integration_and_Mobile_Install_Report.pdf') as pdf:
    print('Total pages:', len(pdf.pages))
    for i, p in enumerate(pdf.pages):
        text = p.extract_text() or ""
        print(f"Page {i+1}: length={len(text)}, images={len(p.images)}")
        first_line = text.split("\n")[0] if text else "EMPTY"
        print(f"  First line: {first_line[:80]}")
