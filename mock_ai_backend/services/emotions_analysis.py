import cv2
import numpy as np
from fer import FER
from collections import Counter

def get_most_frequent_emotion(emotions):
    if not emotions:
        return "N/A"
    counter = Counter(emotions)
    most_common = counter.most_common(1)[0][0]
    return most_common

def analyze_video(video_path):
    detector = FER(mtcnn=True)
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        return {"error": f"Unable to open video file: {video_path}"}

    results = []
    dominant_emotions = []

    frame_count = 0
    success = True

    while success:
        success, frame = cap.read()
        if not success:
            break

        # Skip every other frame to improve performance
        if frame_count % 10 != 0:
            frame_count += 1
            continue

        try:
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            emotions = detector.detect_emotions(rgb_frame)

            if emotions:
                top_emotion = max(emotions[0]["emotions"], key=emotions[0]["emotions"].get)
                results.append(emotions[0]["emotions"])
                dominant_emotions.append(top_emotion)
        except Exception as e:
            print(f"Error processing frame {frame_count}: {e}")

        frame_count += 1

    cap.release()

    return {
        "emotions": results,
        "dominant_emotions": dominant_emotions,
        "summary_emotion": get_most_frequent_emotion(dominant_emotions)
    }
