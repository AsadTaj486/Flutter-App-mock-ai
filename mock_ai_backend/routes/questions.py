# routes/questions.py

from fastapi import APIRouter, Body
from services.question_generator import generate_questions

router = APIRouter()

@router.post("/generate")
def generate(payload: dict = Body(...)):
    resume = payload.get("resume", "")
    jd = payload.get("jd", "")
    try:
        result = generate_questions(resume, jd)
        return {"questions": result}
    except Exception as e:
        return {"error": str(e)}
