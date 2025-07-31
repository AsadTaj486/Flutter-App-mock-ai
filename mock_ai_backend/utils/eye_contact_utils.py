import cv2
import mediapipe as mp

mp_face_mesh = mp.solutions.face_mesh

def estimate_eye_contact(frame) -> float:
    with mp_face_mesh.FaceMesh(static_image_mode=True, max_num_faces=1) as face_mesh:
        results = face_mesh.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        if results.multi_face_landmarks:
            return 1.0  # Eye contact detected
        else:
            return 0.0  # No face or eye contact
