# utils/facial_emotion_utils.py

from deepface import DeepFace
import cv2

def analyze_facial_emotions(video_path):
    cap = cv2.VideoCapture(video_path)
    emotions = []

    frame_interval = 10  # Process every 10th frame
    frame_count = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        if frame_count % frame_interval == 0:
            try:
                analysis = DeepFace.analyze(frame, actions=['emotion'], enforce_detection=False)
                if isinstance(analysis, list):
                    emotions.append(analysis[0]['dominant_emotion'])
                else:
                    emotions.append(analysis['dominant_emotion'])
            except Exception as e:
                print(f"DeepFace error: {e}")
        frame_count += 1

    cap.release()
    if not emotions:
        return "N/A"

    return max(set(emotions), key=emotions.count)
