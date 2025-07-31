from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, EmailStr
from typing import Optional
import hashlib
import secrets

router = APIRouter()

# Pydantic models for request/response
class UserSignup(BaseModel):
    email: EmailStr
    password: str
    name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    token: Optional[str] = None

# Simple in-memory storage (replace with your database later)
users_db = {}

def hash_password(password: str) -> str:
    """Simple password hashing"""
    return hashlib.sha256(password.encode()).hexdigest()

def generate_token() -> str:
    """Generate a simple token"""
    return secrets.token_urlsafe(32)

@router.post("/signup", response_model=UserResponse)
async def signup(user_data: UserSignup):
    """User signup endpoint"""
    try:
        # Check if user already exists
        if user_data.email in users_db:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User with this email already exists"
            )
        
        # Create new user
        user_id = secrets.token_urlsafe(8)
        hashed_password = hash_password(user_data.password)
        token = generate_token()
        
        # Store user
        users_db[user_data.email] = {
            "id": user_id,
            "email": user_data.email,
            "name": user_data.name,
            "password": hashed_password,
            "token": token
        }
        
        print(f"User created: {user_data.email}")  # Debug log
        
        return UserResponse(
            id=user_id,
            email=user_data.email,
            name=user_data.name,
            token=token
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Signup error: {str(e)}")  # Debug log
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Signup failed: {str(e)}"
        )

@router.post("/login", response_model=UserResponse)
async def login(user_data: UserLogin):
    """User login endpoint"""
    try:
        print(f"Login attempt for: {user_data.email}")  # Debug log
        
        # Check if user exists
        if user_data.email not in users_db:
            print(f"User not found: {user_data.email}")  # Debug log
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        user = users_db[user_data.email]
        hashed_password = hash_password(user_data.password)
        
        # Verify password
        if user["password"] != hashed_password:
            print(f"Invalid password for: {user_data.email}")  # Debug log
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Generate new token
        token = generate_token()
        users_db[user_data.email]["token"] = token
        
        print(f"Login successful for: {user_data.email}")  # Debug log
        
        return UserResponse(
            id=user["id"],
            email=user["email"],
            name=user["name"],
            token=token
        )
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Login error: {str(e)}")  # Debug log
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {str(e)}"
        )

@router.post("/logout")
async def logout():
    """User logout endpoint"""
    return {"message": "Logged out successfully"}

# Debug endpoint to see registered users
@router.get("/debug/users")
async def debug_users():
    """Debug endpoint - remove in production"""
    return {
        "total_users": len(users_db),
        "emails": list(users_db.keys())
    }