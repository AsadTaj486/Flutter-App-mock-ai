from deepface import DeepFace
import cv2
import numpy as np
import mediapipe as mp

import os

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Suppress TensorFlow logs


# Initialize MediaPipe Pose (if not already done)
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(static_image_mode=False, model_complexity=1)

def estimate_confidence(frame) -> float:
    """Estimate confidence based on multiple factors"""
    try:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Get emotion analysis
        analysis = DeepFace.analyze(img_path=rgb_frame, actions=['emotion'], enforce_detection=False)
        emotions = analysis[0]['emotion']
        
        # Get pose landmarks
        pose_results = pose.process(rgb_frame)
        
        confidence_score = 0.0
        
        # Factor 1: Emotion confidence (happy, neutral = confident; fear, sad = not confident)
        emotion_confidence = 0.0
        if 'happy' in emotions:
            emotion_confidence += emotions['happy'] * 0.01
        if 'neutral' in emotions:
            emotion_confidence += emotions['neutral'] * 0.008
        if 'fear' in emotions:
            emotion_confidence -= emotions['fear'] * 0.01
        if 'sad' in emotions:
            emotion_confidence -= emotions['sad'] * 0.008
            
        emotion_confidence = max(0.0, min(1.0, emotion_confidence))
        
        # Factor 2: Posture confidence (call the posture function)
        posture_confidence = estimate_posture_for_confidence(frame, pose_results)
        
        # Factor 3: Head position stability (confident people hold head steady)
        head_stability = 0.5  # Default middle value
        if pose_results.pose_landmarks:
            nose = pose_results.pose_landmarks.landmark[mp_pose.PoseLandmark.NOSE]
            # Higher nose position often indicates more confident head posture
            head_stability = max(0.0, min(1.0, 1.0 - nose.y))
        
        # Combine factors
        confidence_score = (emotion_confidence * 0.4 + 
                          posture_confidence * 0.4 + 
                          head_stability * 0.2)
        
        return min(1.0, max(0.0, confidence_score))
        
    except Exception as e:
        print(f"Confidence estimation error: {e}")
        return 0.0

def estimate_posture_for_confidence(frame, pose_results) -> float:
    """Helper function for posture in confidence calculation"""
    try:
        if pose_results.pose_landmarks:
            landmarks = pose_results.pose_landmarks.landmark
            
            left_shoulder = landmarks[mp_pose.PoseLandmark.LEFT_SHOULDER]
            right_shoulder = landmarks[mp_pose.PoseLandmark.RIGHT_SHOULDER]
            nose = landmarks[mp_pose.PoseLandmark.NOSE]
            
            shoulder_diff = abs(left_shoulder.y - right_shoulder.y)
            shoulder_center_x = (left_shoulder.x + right_shoulder.x) / 2
            head_alignment = abs(nose.x - shoulder_center_x)
            
            shoulder_score = max(0.0, 1.0 - (shoulder_diff * 10))
            head_score = max(0.0, 1.0 - (head_alignment * 5))
            
            return (shoulder_score + head_score) / 2
        return 0.5
    except:
        return 0.5