# 📝 routes/resume.py
from fastapi import APIRouter, UploadFile, File
from services.resume_parser import parse_resume

router = APIRouter()  # ✅ THIS LINE WAS MISSING

@router.post("/upload")
async def upload_resume(file: UploadFile = File(...)):
    content = await file.read()
    parsed_data = parse_resume(content)
    return {"parsed_resume": parsed_data}
