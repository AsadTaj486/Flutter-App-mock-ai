# 🔎 services/jd_parser.py
# ✅ services/jd_parser.py

def parse_jd(text: str):
    keywords = [word for word in text.split() if word.istitle()]
    return {"keywords": keywords}
