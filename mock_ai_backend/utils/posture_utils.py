import cv2
import mediapipe as mp

import os

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Suppress TensorFlow logs

# Initialize MediaPipe Face Mesh
mp_face_mesh = mp.solutions.face_mesh
face_mesh = mp_face_mesh.FaceMesh(
    static_image_mode=False,
    max_num_faces=1,
    refine_landmarks=True,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

def estimate_posture(frame) -> float:
    """Simple posture estimation based on face position and stability"""
    try:
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = face_mesh.process(rgb_frame)
        
        if results.multi_face_landmarks:
            landmarks = results.multi_face_landmarks[0]
            h, w = frame.shape[:2]
            
            # Get face center
            nose = landmarks.landmark[1]
            face_center_x = nose.x * w
            face_center_y = nose.y * h
            
            # Check if face is centered horizontally (good posture indicator)
            frame_center_x = w / 2
            horizontal_deviation = abs(face_center_x - frame_center_x) / w
            horizontal_score = max(0.0, 1.0 - (horizontal_deviation * 2))
            
            # Check if face is at good vertical position (not too high/low)
            frame_center_y = h / 2
            vertical_deviation = abs(face_center_y - frame_center_y) / h
            vertical_score = max(0.0, 1.0 - (vertical_deviation * 1.5))
            
            # Get left and right eye for head tilt
            left_eye = landmarks.landmark[33]
            right_eye = landmarks.landmark[263]
            
            eye_y_diff = abs((left_eye.y * h) - (right_eye.y * h))
            eye_distance = abs((left_eye.x * w) - (right_eye.x * w))
            
            if eye_distance > 0:
                tilt_ratio = eye_y_diff / eye_distance
                tilt_score = max(0.0, 1.0 - (tilt_ratio * 8))
            else:
                tilt_score = 0.5
            
            # Combine scores
            posture_score = (horizontal_score * 0.3 + vertical_score * 0.3 + tilt_score * 0.4)
            
            print(f"Simple Posture - H:{horizontal_score:.2f}, V:{vertical_score:.2f}, T:{tilt_score:.2f}, Final:{posture_score:.2f}")
            
            return min(1.0, max(0.2, posture_score))  # Minimum 0.2 to avoid always 0
            
        return 0.2  # Default minimum value
        
    except Exception as e:
        print(f"Simple posture error: {e}")
        return 0.2