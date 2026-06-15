import json
import os
import hashlib
import firebase_admin
from firebase_admin import auth as fb_auth, credentials
from fastapi import Depends, HTTPException, Header, status
from app.core.supabase_client import supabase

# Load environment variables
_sa_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT_JSON")
if _sa_json:
    try:
        cred = credentials.Certificate(json.loads(_sa_json))
        firebase_admin.initialize_app(cred)
    except Exception as e:
        print(f"Error initializing Firebase from JSON env: {e}")
else:
    path = os.environ.get("FIREBASE_SERVICE_ACCOUNT_PATH", "./firebase-service-account.json")
    if os.path.exists(path):
        try:
            cred = credentials.Certificate(path)
            firebase_admin.initialize_app(cred)
        except Exception as e:
            print(f"Error initializing Firebase from path {path}: {e}")
    else:
        print("Warning: Firebase service account path not found.")

async def get_or_create_user(firebase_uid: str, email: str = None, name: str = None) -> dict:
    """
    Find or provision a user in users table by firebase_uid.
    Ref: Section 3 Auth Flow - just-in-time provisioning
    """
    try:
        response = supabase.table("users").select("*").eq("firebase_uid", firebase_uid).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
        
        # Provision new user
        new_user = {
            "firebase_uid": firebase_uid,
            "email": email,
            "full_name": name,
            "role": "family"
        }
        insert_response = supabase.table("users").insert(new_user).execute()
        if insert_response.data and len(insert_response.data) > 0:
            return insert_response.data[0]
        return new_user
    except Exception as e:
        print(f"Error in get_or_create_user: {e}")
        return {"id": "mock-uuid-user", "firebase_uid": firebase_uid, "email": email, "full_name": name}

async def get_current_user(authorization: str = Header(...)) -> dict:
    """
    Verify Firebase token and retrieve current user context.
    Ref: Section 3 of design doc
    """
    if not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    token = authorization.split(" ", 1)[1]
    try:
        decoded = fb_auth.verify_id_token(token)
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid Firebase token")

    firebase_uid = decoded["uid"]
    user = await get_or_create_user(firebase_uid, decoded.get("email"), decoded.get("name"))
    return user

def verify_device_key(incoming_key: str, stored_hash: str) -> bool:
    """
    Verify plain text incoming device key with SHA256 stored hash in DB.
    Ref: Section 3 & Section 2 CAMERAS table
    """
    return hashlib.sha256(incoming_key.encode()).hexdigest() == stored_hash

async def verify_device_key_dependency(x_device_key: str = Header(None, alias="X-Device-Key")) -> dict:
    """
    Dependency to verify device API Key in incoming requests.
    Checks the cameras table for active keys.
    """
    if not x_device_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "UNAUTHORIZED", "message": "Missing X-Device-Key header"}}
        )
    
    # Check key by hashing and querying the cameras table
    hashed_key = hashlib.sha256(x_device_key.encode()).hexdigest()
    try:
        response = supabase.table("cameras").select("*").eq("device_api_key_hash", hashed_key).execute()
        if not response.data or len(response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail={"error": {"code": "INVALID_DEVICE_KEY", "message": "Device key không hợp lệ hoặc camera chưa đăng ký"}}
            )
        return response.data[0]
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        # Development fallback
        from app.core.config import settings
        if settings.APP_ENV != "production" and x_device_key.startswith("sg_dev_"):
            print(f"Error querying cameras table: {e}. Fallback to mock.")
            return {"id": "mock-camera-id", "household_id": "mock-household-id", "name": "Mock Camera"}
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": {"code": "INVALID_DEVICE_KEY", "message": "Device key không hợp lệ hoặc camera chưa đăng ký"}}
        )
