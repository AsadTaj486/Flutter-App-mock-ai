from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Any
from services.feedback_generator import generate_feedback, summarize_results

router = APIRouter()


class ResultItem(BaseModel):
    eye_contact: float
    smile: float
    confidence: float
    posture: float
    hand_movement: float
    head_nod: float


class FeedbackRequest(BaseModel):
    results: List[ResultItem]


@router.post("/generate")
async def get_feedback(data: FeedbackRequest):
    result_dicts = [item.dict() for item in data.results]
    summarized = summarize_results(result_dicts)
    feedback = generate_feedback(summarized)
    return {
        "result": summarized,
        "feedback": feedback
    }
