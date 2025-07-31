# services/voice_to_text.py

import os
import tempfile
import shutil
from pydub import AudioSegment
import speech_recognition as sr
import moviepy.editor as mp
import logging

logger = logging.getLogger(__name__)

def extract_audio_from_video(video_path: str, audio_path: str):
    """Extract audio from video file"""
    try:
        clip = mp.VideoFileClip(video_path)
        clip.audio.write_audiofile(audio_path, verbose=False, logger=None)
        clip.close()
    except Exception as e:
        raise Exception(f"Audio extraction failed: {str(e)}")

def convert_voice_to_text(video_path: str) -> str:
    """
    Convert video file to text
    Now accepts video file path instead of UploadFile
    """
    try:
        temp_dir = "temp_voice"
        os.makedirs(temp_dir, exist_ok=True)
        
        # Extract audio from video
        audio_path = os.path.join(temp_dir, "temp_audio.wav")
        extract_audio_from_video(video_path, audio_path)
        
        # Convert to mono 16kHz for better recognition
        audio = AudioSegment.from_file(audio_path)
        audio = audio.set_channels(1).set_frame_rate(16000)
        
        # Create temporary WAV file
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_wav:
            audio.export(temp_wav.name, format="wav")
            
            # Initialize speech recognizer
            recognizer = sr.Recognizer()
            
            with sr.AudioFile(temp_wav.name) as source:
                # Adjust for ambient noise
                recognizer.adjust_for_ambient_noise(source)
                audio_data = recognizer.record(source)
                
                try:
                    # First try Urdu
                    text = recognizer.recognize_google(audio_data, language="ur-PK")
                    logger.info(f"🎤 Urdu text recognized: {text[:50]}...")
                    return text
                except sr.UnknownValueError:
                    # If Urdu fails, try English
                    try:
                        text = recognizer.recognize_google(audio_data, language="en-US")
                        logger.info(f"🎤 English text recognized: {text[:50]}...")
                        return text
                    except sr.UnknownValueError:
                        logger.warning("🎤 No speech could be recognized")
                        return ""
            
            # Clean up temp file
            if os.path.exists(temp_wav.name):
                os.unlink(temp_wav.name)
                
        # Clean up audio file
        if os.path.exists(audio_path):
            os.remove(audio_path)
            
    except sr.UnknownValueError:
        logger.warning("🎤 Speech recognition could not understand audio")
        return ""
    except sr.RequestError as e:
        logger.error(f"🎤 Speech recognition service error: {str(e)}")
        return ""
    except Exception as e:
        logger.error(f"🎤 Voice to text conversion error: {str(e)}")
        raise Exception(f"Voice to text conversion error: {str(e)}")
    finally:
        # Clean up temp directory
        if os.path.exists(temp_dir):
            try:
                shutil.rmtree(temp_dir)
            except:
                pass