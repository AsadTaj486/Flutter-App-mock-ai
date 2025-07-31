# ✅ FastAPI imports and setup
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import facial_audio_evaluation
from routes import resume, jd, questions, feedback
from routes import auth  # ← Add this import

app = FastAPI()

# ✅ CORS settings
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ✅ Routers
app.include_router(auth.router, prefix="/auth")  # ← Add this line
app.include_router(resume.router, prefix="/resume")
app.include_router(jd.router, prefix="/jd")
app.include_router(questions.router, prefix="/questions")
# app.include_router(audio_checker.router, prefix="/check")
app.include_router(feedback.router, prefix="/feedback")
app.include_router(facial_audio_evaluation.router, prefix="/emotion")

# ✅ Root route
@app.get("/")
def read_root():
    return {"message": "Mock AI Backend is Running"}