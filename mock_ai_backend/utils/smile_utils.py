import cv2
import numpy as np
import mediapipe as mp

import os

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Suppress TensorFlow logs

# Initialize MediaPipe Face Mesh
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(static_image_mode=False, max_num_faces=1, refine_landmarks=True)

def estimate_smile(frame) -> float:
    """Detect actual smile using facial landmarks"""
    try:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb_frame)
        
        if results.multi_face_landmarks:
            landmarks = results.multi_face_landmarks[0]
            h, w = frame.shape[:2]
            
            # Key points for smile detection
            left_mouth = landmarks.landmark[61]  # Left corner of mouth
            right_mouth = landmarks.landmark[291]  # Right corner of mouth
            top_lip = landmarks.landmark[13]      # Top of upper lip
            bottom_lip = landmarks.landmark[14]   # Bottom of lower lip
            
            # Convert to pixel coordinates
            left_mouth_px = (int(left_mouth.x * w), int(left_mouth.y * h))
            right_mouth_px = (int(right_mouth.x * w), int(right_mouth.y * h))
            top_lip_px = (int(top_lip.x * w), int(top_lip.y * h))
            bottom_lip_px = (int(bottom_lip.x * w), int(bottom_lip.y * h))
            
            # Calculate mouth width and height
            mouth_width = np.sqrt((right_mouth_px[0] - left_mouth_px[0])**2 + 
                                (right_mouth_px[1] - left_mouth_px[1])**2)
            mouth_height = np.sqrt((bottom_lip_px[0] - top_lip_px[0])**2 + 
                                 (bottom_lip_px[1] - top_lip_px[1])**2)
            
            # Smile ratio: wider mouth relative to height indicates smile
            if mouth_height > 0:
                smile_ratio = mouth_width / mouth_height
                # Normalize to 0-1 scale (typical smile ratio is > 3.0)
                smile_score = min(1.0, max(0.0, (smile_ratio - 2.5) / 2.0))
                return smile_score
                
        return 0.0
    except Exception as e:
        print(f"Smile detection error: {e}")
        return 0.0