def summarize_results(results: list) -> dict:
    """
    Averages the list of individual clip/frame results into a single summary result.
    """
    if not results:
        return {}

    total = {
        "eye_contact": 0.0,
        "smile": 0.0,
        "confidence": 0.0,
        "posture": 0.0,
        "hand_movement": 0.0,
        "head_nod": 0.0,
    }
    count = len(results)

    for r in results:
        for key in total:
            total[key] += r.get(key, 0.0)

    average = {k: round(v / count, 2) for k, v in total.items()}
    return average


def generate_feedback(result: dict) -> dict:
    """
    Generates feedback (strengths, weaknesses, suggestions) based on summarized analysis result.
    """
    feedback = {
        "strengths": [],
        "weaknesses": [],
        "suggestions": [],
        "confidence_score": result.get("confidence", 0.5),
    }

    # Eye Contact
    eye_contact = result.get("eye_contact", 0)
    if eye_contact >= 0.7:
        feedback["strengths"].append("Maintains good eye contact")
    else:
        feedback["weaknesses"].append("Poor eye contact")
        feedback["suggestions"].append("Try to maintain eye contact to build connection")

    # Smile
    smile = result.get("smile", 0)
    if smile >= 0.7:
        feedback["strengths"].append("Friendly smile")
    else:
        feedback["suggestions"].append("Smile occasionally to appear more approachable")

    # Voice Emotion / Confidence
    confidence = result.get("confidence", 0)
    if confidence >= 0.75:
        feedback["strengths"].append("Confident speaking")
    else:
        feedback["suggestions"].append("Work on projecting more confidence in speech")

    # Posture
    posture = result.get("posture", 0)
    if posture >= 0.7:
        feedback["strengths"].append("Professional posture")
    else:
        feedback["suggestions"].append("Maintain upright posture for confidence")

    # Hand Movement
    hand_movement = result.get("hand_movement", 0)
    if hand_movement >= 0.6:
        feedback["strengths"].append("Good hand gestures")
    else:
        feedback["suggestions"].append("Use expressive but controlled hand gestures")

    # Head Nod
    head_nod = result.get("head_nod", 0)
    if head_nod < 0.3:
        feedback["suggestions"].append("Nod occasionally to show engagement")

    # General
    feedback["suggestions"].append("Practice concise answers")
    feedback["suggestions"].append("Maintain steady body posture")

    return feedback
