# script/predict_emotion.py

import cv2
import numpy as np
import os
import tensorflow as tf
from keras.models import load_model
from keras.preprocessing.image import img_to_array

from utils.smile_utils import estimate_smile
from utils.eye_contact_utils import estimate_eye_contact
from utils.hand_movement_utils import estimate_hand_movement
from utils.head_nod_utils import estimate_head_nod
from utils.confidence_utils import estimate_confidence

os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # 2 = Hide INFO and WARNING

# Load emotion model
model_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'models', 'facial_emotion_model.h5'))
model = load_model(model_path)

def extract_frames(video_path, max_frames=30):
    cap = cv2.VideoCapture(video_path)
    frames = []
    total = 0

    while cap.isOpened() and len(frames) < max_frames:
        ret, frame = cap.read()
        if not ret:
            break
        total += 1
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        resized = cv2.resize(gray, (48, 48))
        frames.append(resized)

    cap.release()
    return frames, total

EMOTION_LABELS = ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral']

def predict_emotions_on_frames(file_paths):
    global detected_emotions
    detected_emotions = []

    for path in file_paths:
        frames, total = extract_frames(path)
        smile_frames = 0
        eye_contact_frames = 0
        # hand_movement_frames = 0  # Commented out for now
        # head_nod_frames = 0       # Commented out for now
        
        total_frames = len(frames)

        for frame_idx, frame in enumerate(frames):
            img = frame.reshape(1, 48, 48, 1) / 255.0
            preds = model.predict(img, verbose=0)
            label_idx = np.argmax(preds)
            label = EMOTION_LABELS[label_idx]
            detected_emotions.append(label)

            try:
                # ✅ These should work fine
                if estimate_smile(label) == "Yes":
                    smile_frames += 1
                    
                if estimate_eye_contact(frame) == "Yes":
                    eye_contact_frames += 1
                    
                # ✅ Comment out problematic functions for now
                # if estimate_hand_movement(frame, frame_idx) == "Moderate":
                #     hand_movement_frames += 1
                    
                # if estimate_head_nod(frame, frame_idx) == "Yes":
                #     head_nod_frames += 1
                    
            except Exception as e:
                print(f"Error processing frame {frame_idx}: {str(e)}")
                continue

    return detected_emotions


def format_final_result(all_results):
    # This function can be used if needed in other places
    emotion_labels = ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral']
    counts = np.bincount(all_results)
    top_emotion = emotion_labels[np.argmax(counts)] if len(counts) > 0 else "Unknown"

    return {
        "dominant_emotion": top_emotion
    }
