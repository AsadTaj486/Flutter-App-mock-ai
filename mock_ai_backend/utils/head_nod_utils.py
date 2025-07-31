import mediapipe as mp
import cv2

mp_face_mesh = mp.solutions.face_mesh
prev_nose_y = None

def estimate_head_nod(frame) -> float:
    global prev_nose_y
    with mp_face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1) as face_mesh:
        results = face_mesh.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        if results.multi_face_landmarks:
            nose = results.multi_face_landmarks[0].landmark[1]  # Nose tip
            current_y = nose.y
            if prev_nose_y is not None:
                delta = abs(current_y - prev_nose_y)
                prev_nose_y = current_y
                if delta > 0.015:  # Threshold for nodding motion
                    return 1.0
            prev_nose_y = current_y
    return 0.0
