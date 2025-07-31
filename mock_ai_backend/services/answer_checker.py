# services/answer_checker.py

import os
import requests
import json
import logging
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

TOGETHER_API_URL = "https://api.together.xyz/v1/chat/completions"
TOGETHER_API_KEY = os.getenv("TOGETHER_API_KEY")

# Available serverless models (no dedicated endpoint required)
AVAILABLE_MODELS = [
    "NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO",  # Recommended
    "mistralai/Mixtral-8x7B-Instruct-v0.1",         # Good performance
    "meta-llama/Llama-2-7b-chat-hf",                 # Faster, lighter
    "microsoft/DialoGPT-medium",                     # Alternative
    "togethercomputer/RedPajama-INCITE-Chat-3B-v1"  # Lightweight
]

# Use the first available model
MODEL = AVAILABLE_MODELS[0]  # NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO

def evaluate_answer(question: str, answer: str) -> dict:
    """
    Evaluate if the answer is correct for the given question
    Returns detailed evaluation with score and feedback
    """
    try:
        if not TOGETHER_API_KEY:
            raise Exception("TOGETHER_API_KEY environment variable not set")
            
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {TOGETHER_API_KEY}",
        }

        system_prompt = """You are an interview evaluator. Analyze the provided answer against the given question and provide evaluation in JSON format.

Return your response in this exact JSON structure:
{
    "status": "Correct" | "Partially Correct" | "Incorrect",
    "score": 0-100,
    "feedback": "Detailed feedback in English only",
    "reasoning": "Why you gave this evaluation",
    "suggestions": "Suggestions for improvement (if any)"
}

Consider:
- Content accuracy and relevance
- Completeness of the answer
- Communication clarity
- Both English and Urdu responses from candidates are acceptable

Be concise but thorough in your evaluation."""

        payload = {
            "model": MODEL,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": f"Question: {question}\nAnswer: {answer}"}
            ],
            "temperature": 0.3,
            "max_tokens": 500  # Reduced for better performance
        }

        logger.info(f"📝 Evaluating answer using model: {MODEL}")
        logger.info(f"📋 Question: {question[:50]}...")
        
        response = requests.post(TOGETHER_API_URL, headers=headers, data=json.dumps(payload), timeout=45)

        if response.status_code != 200:
            logger.error(f"❌ Together AI API error: {response.status_code}")
            logger.error(f"Response: {response.text}")
            
            # Try with a different model if the first one fails
            if response.status_code == 400 and len(AVAILABLE_MODELS) > 1:
                logger.info("🔄 Trying with alternative model...")
                payload["model"] = AVAILABLE_MODELS[1]  # Try second model
                response = requests.post(TOGETHER_API_URL, headers=headers, data=json.dumps(payload), timeout=45)
                
                if response.status_code != 200:
                    raise Exception(f"Together AI evaluation failed with multiple models: {response.text}")
            else:
                raise Exception(f"Together AI evaluation failed: {response.text}")

        result = response.json()
        
        if 'choices' not in result or not result['choices']:
            raise Exception("Invalid response format from Together AI")
            
        evaluation_text = result['choices'][0]['message']['content']
        
        try:
            # Try to parse as JSON
            evaluation_json = json.loads(evaluation_text)
            logger.info(f"✅ Answer evaluation completed: {evaluation_json.get('status', 'Unknown')}")
            return evaluation_json
        except json.JSONDecodeError:
            # If JSON parsing fails, create structured response from text
            logger.warning("⚠️ AI response was not valid JSON, parsing text response")
            
            # Try to extract meaningful information from text
            status = "Partially Correct"
            score = 60  # Default score
            
            # Simple text analysis to determine status
            text_lower = evaluation_text.lower()
            if "correct" in text_lower and "incorrect" not in text_lower:
                status = "Correct"
                score = 80
            elif "incorrect" in text_lower:
                status = "Incorrect"
                score = 30
                
            return {
                "status": status,
                "score": score,
                "feedback": evaluation_text[:500],  # Limit feedback length
                "reasoning": "Extracted from text response due to format issue",
                "suggestions": "Please provide more specific answers for better evaluation"
            }

    except requests.exceptions.Timeout:
        logger.error("⏰ Together AI API timeout")
        return {
            "status": "Error",
            "score": 0,
            "feedback": "Evaluation timed out. Please try again.",
            "reasoning": "API timeout",
            "suggestions": "Please try again"
        }
    except requests.exceptions.ConnectionError:
        logger.error("🔌 Connection error to Together AI")
        return {
            "status": "Error",
            "score": 0,
            "feedback": "Connection error. Please check your internet connection.",
            "reasoning": "Connection error",
            "suggestions": "Please check your internet connection and try again"
        }
    except Exception as e:
        logger.error(f"❌ Answer evaluation error: {str(e)}")
        return {
            "status": "Error",
            "score": 0,
            "feedback": f"Evaluation failed: {str(e)[:200]}",  # Limit error message
            "reasoning": f"System error: {str(e)[:100]}",
            "suggestions": "Please check your API key and try again"
        }


def test_together_api():
    """Test function to check if Together AI API is working"""
    try:
        if not TOGETHER_API_KEY:
            return False, "TOGETHER_API_KEY not set"
            
        headers = {
            "Content-Type": "application/json",
            "Authorization": f"Bearer {TOGETHER_API_KEY}",
        }
        
        test_payload = {
            "model": MODEL,
            "messages": [{"role": "user", "content": "Hello, just testing the API."}],
            "max_tokens": 50
        }
        
        response = requests.post(TOGETHER_API_URL, headers=headers, data=json.dumps(test_payload), timeout=30)
        
        if response.status_code == 200:
            return True, "API working correctly"
        else:
            return False, f"API error: {response.status_code} - {response.text}"
            
    except Exception as e:
        return False, f"Connection error: {str(e)}"


if __name__ == "__main__":
    # Test the API when running this file directly
    success, message = test_together_api()
    print(f"Together AI API Test: {'✅ PASS' if success else '❌ FAIL'}")
    print(f"Message: {message}")