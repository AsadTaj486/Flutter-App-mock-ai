# 🧾 services/resume_parser.py
import fitz  # PyMuPDF

def parse_resume(file_bytes: bytes):
    doc = fitz.open(stream=file_bytes, filetype="pdf")
    text = "\n".join([page.get_text() for page in doc])
    return {"text": text}
