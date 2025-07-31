# 🤖 services/question_generator.py

import os
from dotenv import load_dotenv
import together

# Load environment variables from .env file
load_dotenv()

# Set your API key properly (recommended way)
os.environ["TOGETHER_API_KEY"] = os.getenv("TOGETHER_API_KEY")

# Configure Together API
together.api_key = os.getenv("TOGETHER_API_KEY")

def generate_questions(resume_text: str, jd_text: str):
    prompt = f"""
You are an AI recruiter.

Given the following resume and job description, generate exactly 5 interview questions:
- First 3 should be technical questions.
- Last 2 should be behavioral questions.

Return **only** the list of questions, numbered from 1 to 5, with no section headers or extra text.

Resume:
{resume_text}

Job Description:
{jd_text}
"""

    # Choose a supported model
    response = together.Complete.create(
        model="mistralai/Mixtral-8x7B-Instruct-v0.1",  # ✅ Replace with your available model
        prompt=prompt,
        max_tokens=300,
        temperature=0.7,
    )

   # ✅ Use dictionary access, not object-style
    text = response['choices'][0]['text']
    # Split the string into a list of questions
    questions = [q.strip() for q in text.split('\n') if q.strip() and '?' in q]
    return questions
