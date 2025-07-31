import cv2
import mediapipe as mp

mp_hands = mp.solutions.hands

def estimate_hand_movement(frame) -> float:
    with mp_hands.Hands(static_image_mode=True, max_num_hands=2) as hands:
        results = hands.process(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        if results.multi_hand_landmarks:
            return 1.0  # Hand movement detected
        return 0.0
