# schemas/feedback.py

from pydantic import BaseModel
from typing import Dict

class FeedbackRequest(BaseModel):
    result: Dict
