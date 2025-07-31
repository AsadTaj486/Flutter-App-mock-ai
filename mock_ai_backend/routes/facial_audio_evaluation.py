import os
import shutil
import logging
import traceback
import tempfile
from pathlib import Path
from fastapi import APIRouter, UploadFile, File, Form, HTTPException
from typing import List, Optional
from concurrent.futures import ThreadPoolExecutor, as_completed
import asyncio
from datetime import datetime

# Import your existing modules
try:
    from script.predict_emotion import predict_emotions_on_frames
    from utils.video_analysis_utils import analyze_video
    from services.feedback_generator import generate_feedback
    from services.audio_to_text import convert_voice_to_text
    from services.answer_checker import evaluate_answer
except ImportError as e:
    logging.error(f"Failed to import required modules: {e}")
    raise

router = APIRouter()

# Enhanced logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class VideoProcessingError(Exception):
    """Custom exception for video processing errors"""
    pass

def validate_video_file(file_path: str) -> bool:
    """Validate if the video file is valid and accessible"""
    try:
        if not os.path.exists(file_path):
            logger.error(f"File does not exist: {file_path}")
            return False
        
        file_size = os.path.getsize(file_path)
        if file_size == 0:
            logger.error(f"File is empty: {file_path}")
            return False
        
        # Check if file is readable
        with open(file_path, 'rb') as f:
            f.read(1024)  # Try to read first 1KB
        
        logger.info(f"Video file validation passed: {file_path} ({file_size} bytes)")
        return True
        
    except Exception as e:
        logger.error(f"Video file validation failed: {e}")
        return False

def safe_predict_emotions(video_path: str) -> List[dict]:
    """Safely predict emotions with error handling"""
    try:
        logger.info(f"🎭 Starting emotion prediction for: {video_path}")
        result = predict_emotions_on_frames([video_path])
        logger.info(f"✅ Emotion prediction completed successfully")
        return result if result else []
    except Exception as e:
        logger.error(f"❌ Emotion prediction failed: {str(e)}")
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return [{
            "timestamp": 0,
            "emotion": "neutral",
            "confidence": 0.0,
            "error": f"Emotion prediction failed: {str(e)}"
        }]

def safe_analyze_video(video_path: str) -> dict:
    """Safely analyze video with error handling"""
    try:
        logger.info(f"📊 Starting multimodal analysis for: {video_path}")
        result = analyze_video(video_path)
        logger.info(f"✅ Multimodal analysis completed successfully")
        return result if result else {}
    except Exception as e:
        logger.error(f"❌ Multimodal analysis failed: {str(e)}")
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return {
            "eye_contact": 0.0,
            "smile": 0.0,
            "posture": 0.0,
            "confidence": 0.0,
            "hand_movement": 0.0,
            "head_nod": 0.0,
            "error": f"Video analysis failed: {str(e)}"
        }

def safe_convert_voice_to_text(video_path: str) -> str:
    """Safely convert voice to text with error handling"""
    try:
        logger.info(f"🎤 Starting audio conversion for: {video_path}")
        transcript = convert_voice_to_text(video_path)
        logger.info(f"✅ Audio conversion completed: {len(transcript) if transcript else 0} characters")
        return transcript if transcript else ""
    except Exception as e:
        logger.error(f"❌ Audio conversion failed: {str(e)}")
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return ""

def safe_evaluate_answer(question: str, transcript: str) -> dict:
    """Safely evaluate answer with error handling"""
    try:
        if not transcript or transcript.strip() == "":
            return {
                "status": "No Audio",
                "score": 0,
                "feedback": "No speech detected in the video",
                "reasoning": "No transcript available for evaluation",
                "suggestions": "Ensure microphone is working and speak clearly"
            }
        
        logger.info(f"📝 Starting answer evaluation...")
        result = evaluate_answer(question, transcript)
        logger.info(f"✅ Answer evaluation completed with score: {result.get('score', 0)}")
        return result
    except Exception as e:
        logger.error(f"❌ Answer evaluation failed: {str(e)}")
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return {
            "status": "Error",
            "score": 0,
            "feedback": f"Evaluation error: {str(e)}",
            "reasoning": f"System error during evaluation: {str(e)}",
            "suggestions": "Please try again later"
        }

def safe_generate_feedback(analysis: dict) -> dict:
    """Safely generate feedback with error handling"""
    try:
        logger.info(f"💬 Starting feedback generation...")
        result = generate_feedback(analysis)
        logger.info(f"✅ Feedback generation completed")
        return result if result else {
            "overall_score": 0,
            "strengths": [],
            "weaknesses": ["Analysis incomplete"],
            "suggestions": ["Please try recording again"]
        }
    except Exception as e:
        logger.error(f"❌ Feedback generation failed: {str(e)}")
        logger.error(f"❌ Traceback: {traceback.format_exc()}")
        return {
            "overall_score": 0,
            "strengths": [],
            "weaknesses": [f"Feedback generation failed: {str(e)}"],
            "suggestions": ["Please try again later"]
        }

def create_safe_temp_directory() -> str:
    """Create a safe temporary directory with proper permissions"""
    try:
        # Use system temp directory for better reliability
        temp_dir = tempfile.mkdtemp(prefix="interview_video_")
        logger.info(f"Created temporary directory: {temp_dir}")
        return temp_dir
    except Exception as e:
        logger.error(f"Failed to create temp directory: {e}")
        # Fallback to current directory
        fallback_dir = os.path.join(os.getcwd(), "temp_single_upload")
        os.makedirs(fallback_dir, exist_ok=True)
        return fallback_dir

def cleanup_temp_files(temp_dir: str, file_path: str = None):
    """Safely cleanup temporary files and directories"""
    try:
        if file_path and os.path.exists(file_path):
            os.remove(file_path)
            logger.info(f"Removed temp file: {file_path}")
        
        if temp_dir and os.path.exists(temp_dir):
            shutil.rmtree(temp_dir, ignore_errors=True)
            logger.info(f"Removed temp directory: {temp_dir}")
    except Exception as e:
        logger.warning(f"Cleanup warning (non-critical): {e}")

# NEW ENDPOINT: Enhanced Single Video Analysis
@router.post("/analyze-single")
async def analyze_single_video(
    video: UploadFile = File(...),
    question: str = Form(...),
    question_index: int = Form(...)
):
    """
    Enhanced single video analysis endpoint with comprehensive error handling
    """
    temp_dir = None
    file_path = None
    
    try:
        # Input validation
        if not video:
            raise HTTPException(status_code=400, detail="No video file provided")
        
        if not question or question.strip() == "":
            raise HTTPException(status_code=400, detail="Question is required")
        
        if question_index < 0:
            raise HTTPException(status_code=400, detail="Invalid question index")
        
        logger.info(f"🎯 Starting single video analysis for question {question_index}")
        logger.info(f"📁 Video file: {video.filename}, Content type: {video.content_type}")
        
        # Create secure temp directory
        temp_dir = create_safe_temp_directory()
        
        # Generate safe filename
        original_filename = video.filename or f"question_{question_index}_video.mp4"
        safe_filename = f"video_{question_index}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
        file_path = os.path.join(temp_dir, safe_filename)
        
        # Save uploaded video with size check
        max_file_size = 100 * 1024 * 1024  # 100MB limit
        file_size = 0
        
        try:
            with open(file_path, "wb") as buffer:
                while chunk := await video.read(8192):  # Read in 8KB chunks
                    file_size += len(chunk)
                    if file_size > max_file_size:
                        raise HTTPException(status_code=413, detail="File size too large (max 100MB)")
                    buffer.write(chunk)
            
            logger.info(f"✅ Video saved successfully: {file_path} ({file_size} bytes)")
            
        except Exception as e:
            cleanup_temp_files(temp_dir, file_path)
            logger.error(f"❌ Failed to save video file: {e}")
            raise HTTPException(status_code=500, detail=f"Failed to save video: {str(e)}")
        
        # Validate video file
        if not validate_video_file(file_path):
            cleanup_temp_files(temp_dir, file_path)
            raise HTTPException(status_code=400, detail="Invalid or corrupted video file")
        
        # Process video analysis with timeout
        try:
            logger.info(f"🎬 Starting video processing pipeline...")
            
            # Run all analysis steps with individual error handling
            emotion_result = safe_predict_emotions(file_path)
            multimodal_result = safe_analyze_video(file_path)
            transcript = safe_convert_voice_to_text(file_path)
            
            # Combine analysis results
            combined_analysis = {
                "emotion": emotion_result,
                "transcript": transcript,
                "eye_contact": multimodal_result.get("eye_contact", 0.0),
                "smile": multimodal_result.get("smile", 0.0),
                "posture": multimodal_result.get("posture", 0.0),
                "confidence": multimodal_result.get("confidence", 0.0),
                "hand_movement": multimodal_result.get("hand_movement", 0.0),
                "head_nod": multimodal_result.get("head_nod", 0.0)
            }
            
            # Evaluate answer
            answer_evaluation = safe_evaluate_answer(question, transcript)
            
            # Generate feedback
            feedback = safe_generate_feedback(combined_analysis)
            
            # Success response
            response_data = {
                "success": True,
                "question": question,
                "question_index": question_index,
                "video_name": original_filename,
                "analysis": combined_analysis,
                "answer_evaluation": answer_evaluation,
                "feedback": feedback,
                "timestamp": datetime.now().timestamp(),
                "processing_status": "completed",
                "file_size": file_size,
                "processing_time": datetime.now().isoformat()
            }
            
            logger.info(f"✅ Single video analysis completed successfully for question {question_index}")
            
            # Cleanup before returning
            cleanup_temp_files(temp_dir, file_path)
            
            return response_data
            
        except Exception as processing_error:
            logger.error(f"❌ Video processing pipeline failed: {str(processing_error)}")
            logger.error(f"❌ Processing traceback: {traceback.format_exc()}")
            
            # Cleanup on error
            cleanup_temp_files(temp_dir, file_path)
            
            # Return partial results with error information
            return {
                "success": False,
                "question": question,
                "question_index": question_index,
                "video_name": original_filename,
                "error": f"Processing failed: {str(processing_error)}",
                "analysis": {
                    "emotion": [],
                    "transcript": "",
                    "eye_contact": 0.0,
                    "smile": 0.0,
                    "posture": 0.0,
                    "confidence": 0.0,
                    "hand_movement": 0.0,
                    "head_nod": 0.0,
                    "processing_error": str(processing_error)
                },
                "answer_evaluation": {
                    "status": "Error",
                    "score": 0,
                    "feedback": "Video processing failed",
                    "reasoning": str(processing_error),
                    "suggestions": "Please try recording again"
                },
                "feedback": {
                    "overall_score": 0,
                    "strengths": [],
                    "weaknesses": ["Video processing failed"],
                    "suggestions": ["Please try recording again"]
                },
                "timestamp": datetime.now().timestamp(),
                "processing_status": "failed",
                "file_size": file_size if 'file_size' in locals() else 0
            }
            
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        cleanup_temp_files(temp_dir, file_path)
        raise
        
    except Exception as e:
        logger.exception("🚨 Unexpected server error during single video analysis")
        cleanup_temp_files(temp_dir, file_path)
        
        # Return error response instead of raising HTTPException
        return {
            "success": False,
            "question": question if 'question' in locals() else "Unknown",
            "question_index": question_index if 'question_index' in locals() else -1,
            "video_name": "Unknown",
            "error": f"Internal server error: {str(e)}",
            "analysis": None,
            "answer_evaluation": {
                "status": "Error",
                "score": 0,
                "feedback": "Server error occurred",
                "reasoning": f"Internal server error: {str(e)}",
                "suggestions": "Please try again later"
            },
            "feedback": {
                "overall_score": 0,
                "strengths": [],
                "weaknesses": ["Server error occurred"],
                "suggestions": ["Please try again later"]
            },
            "timestamp": datetime.now().timestamp(),
            "processing_status": "server_error"
        }

def average_analysis(all_results: List[dict]) -> dict:
    """Calculate average analysis from multiple results"""
    if not all_results:
        return {}

    num = len(all_results)
    keys = ["eye_contact", "smile", "posture", "confidence", "hand_movement", "head_nod"]
    avg = {k: 0.0 for k in keys}

    for result in all_results:
        analysis = result["analysis"]
        for key in keys:
            avg[key] += analysis.get(key, 0.0)

    for key in keys:
        avg[key] = round(avg[key] / num, 2)

    all_emotions = []
    all_transcripts = []

    for result in all_results:
        analysis = result["analysis"]
        if analysis.get("emotion"):
            all_emotions.extend(analysis["emotion"])
        if analysis.get("transcript"):
            all_transcripts.append(analysis["transcript"])

    avg["emotion"] = all_emotions
    avg["transcripts"] = all_transcripts
    avg["combined_transcript"] = " ".join(all_transcripts) if all_transcripts else ""

    return avg

def process_single_video(video_path: str, index: int) -> dict:
    """Process a single video file (used for batch processing)"""
    try:
        logger.info(f"🎬 Processing video {index + 1}: {os.path.basename(video_path)}")

        if not validate_video_file(video_path):
            raise VideoProcessingError(f"Invalid video file: {video_path}")

        emotion_result = safe_predict_emotions(video_path)
        multimodal_result = safe_analyze_video(video_path)
        transcript = safe_convert_voice_to_text(video_path)

        combined_analysis = {
            "emotion": emotion_result,
            "transcript": transcript,
            **multimodal_result
        }

        return {
            "video_index": index + 1,
            "video_name": os.path.basename(video_path),
            "analysis": combined_analysis
        }
    except Exception as e:
        logger.error(f"❌ Error analyzing video {video_path}: {str(e)}")
        return {
            "video_index": index + 1,
            "video_name": os.path.basename(video_path),
            "error": f"Failed to process video {index + 1}: {str(e)}",
            "analysis": None
        }

# EXISTING ENDPOINT: Multiple Videos Analysis (enhanced with better error handling)
@router.post("/analyze-interview")
async def analyze_interview(
    videos: List[UploadFile] = File(...),
    question: str = Form(...)
):
    """
    Analyze multiple videos for interview assessment (batch processing)
    """
    temp_dir = None
    file_paths = []
    
    try:
        if not videos:
            raise HTTPException(status_code=400, detail="No video files provided")
        
        if len(videos) > 10:  # Reasonable limit
            raise HTTPException(status_code=400, detail="Too many videos (max 10)")
        
        logger.info(f"🎯 Starting batch interview analysis for {len(videos)} video(s)")
        
        temp_dir = create_safe_temp_directory()
        file_paths = []

        # Save all videos first
        for i, video in enumerate(videos):
            filename = video.filename or f"interview_video_{i}.mp4"
            safe_filename = f"batch_video_{i}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.mp4"
            file_path = os.path.join(temp_dir, safe_filename)
            
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(video.file, buffer)
            
            if validate_video_file(file_path):
                file_paths.append(file_path)
            else:
                logger.warning(f"Skipping invalid video file: {filename}")

        if not file_paths:
            raise HTTPException(status_code=400, detail="No valid video files found")

        # Process videos in parallel
        all_results = []
        with ThreadPoolExecutor(max_workers=3) as executor:  # Limit concurrent processing
            futures = [executor.submit(process_single_video, path, i) for i, path in enumerate(file_paths)]
            for future in as_completed(futures):
                all_results.append(future.result())

        # Clean up files
        cleanup_temp_files(temp_dir)

        successful_results = [res for res in all_results if res["analysis"] is not None]
        if not successful_results:
            raise HTTPException(status_code=500, detail="No valid analysis results found.")

        avg_analysis = average_analysis(successful_results)
        feedback = safe_generate_feedback(avg_analysis)
        answer_evaluation = safe_evaluate_answer(question, avg_analysis.get("combined_transcript", ""))

        return {
            "question": question,
            "videos_processed": len(successful_results),
            "total_videos": len(videos),
            "analysis": avg_analysis,
            "feedback": feedback,
            "answer_evaluation": answer_evaluation,
            "individual_results": [
                {
                    "video_index": res["video_index"],
                    "video_name": res["video_name"],
                    "has_transcript": bool(res["analysis"].get("transcript")) if res["analysis"] else False
                } for res in successful_results
            ],
            "timestamp": datetime.now().timestamp(),
            "processing_status": "completed"
        }

    except HTTPException:
        cleanup_temp_files(temp_dir)
        raise
    except Exception as e:
        logger.exception("🚨 Unexpected server error during batch interview analysis")
        cleanup_temp_files(temp_dir)
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")

# Health check endpoint
@router.get("/health")
async def health_check():
    """Health check endpoint to verify service status"""
    try:
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "service": "emotion_analysis",
            "version": "2.0.0"
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")

# System info endpoint for debugging
@router.get("/system-info")
async def get_system_info():
    """Get system information for debugging purposes"""
    try:
        import psutil
        import platform
        
        return {
            "platform": platform.system(),
            "platform_version": platform.version(),
            "python_version": platform.python_version(),
            "cpu_count": psutil.cpu_count(),
            "memory_total": psutil.virtual_memory().total,
            "memory_available": psutil.virtual_memory().available,
            "disk_usage": psutil.disk_usage('/').percent,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        return {
            "error": f"Could not retrieve system info: {str(e)}",
            "timestamp": datetime.now().isoformat()
        }