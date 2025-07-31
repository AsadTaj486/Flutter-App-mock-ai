import cv2
from utils.eye_contact_utils import estimate_eye_contact
from utils.smile_utils import estimate_smile
from utils.voice_emotion_utils import estimate_voice_emotion
from utils.posture_utils import estimate_posture
from utils.confidence_utils import estimate_confidence
from utils.hand_movement_utils import estimate_hand_movement
from utils.head_nod_utils import estimate_head_nod

def analyze_video(video_path: str) -> dict:
    cap = cv2.VideoCapture(video_path)

    if not cap.isOpened():
        raise ValueError(f"Failed to open video file: {video_path}")

    frame_rate = int(cap.get(cv2.CAP_PROP_FPS))
    frame_interval = max(1, frame_rate * 2)  # Analyze 1 frame every 2 seconds
    max_frames = 60

    results = {
        "eye_contact": [],
        "smile": [],
        "posture": [],
        "confidence": [],
        "hand_movement": [],
        "head_nod": []
    }

    frame_idx = 0
    processed = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        if frame_idx % frame_interval == 0:
            try:
                frame = cv2.resize(frame, (640, 480))  # Resize for faster processing

                results["eye_contact"].append(estimate_eye_contact(frame))
                results["smile"].append(estimate_smile(frame))
                results["posture"].append(estimate_posture(frame))
                results["confidence"].append(estimate_confidence(frame))
                results["hand_movement"].append(estimate_hand_movement(frame))
                results["head_nod"].append(estimate_head_nod(frame))

                processed += 1
                if processed >= max_frames:
                    break
                if processed % 10 == 0:
                    print(f"Processed {processed} frames...")

            except Exception as e:
                print(f"[Frame {frame_idx}] Error during analysis: {e}")

        frame_idx += 1

    cap.release()

    def average(lst):
        try:
            return round(sum(lst) / len(lst), 2) if lst else 0.0
        except Exception as e:
            print(f"Error averaging: {e}")
            return 0.0

    return {
        "eye_contact": average(results["eye_contact"]),
        "smile": average(results["smile"]),
        "posture": average(results["posture"]),
        "confidence": average(results["confidence"]),
        "hand_movement": average(results["hand_movement"]),
        "head_nod": average(results["head_nod"]),
        "voice_emotion": estimate_voice_emotion(video_path)
    }
