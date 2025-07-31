from fastapi import APIRouter, UploadFile, File
from services.jd_parser import parse_jd

router = APIRouter()

import fitz  # PyMuPDF

def extract_text_from_pdf(file_bytes):
    doc = fitz.open(stream=file_bytes, filetype="pdf")
    text = ""
    for page in doc:
        text += page.get_text()
    return text

@router.post("/upload")
async def upload_jd(file: UploadFile = File(...)):
    if not file:
        return {"error": "No file uploaded"}

    try:
        content = await file.read()
        if file.filename.endswith(".pdf"):
            jd_data = extract_text_from_pdf(content)  # ✅ correct for PDFs
        else:
            jd_data = content.decode("utf-8", errors="ignore")

        parsed = parse_jd(jd_data)
        return {"parsed_jd": parsed}
    except Exception as e:
        return {"error": f"Server error: {str(e)}"}
