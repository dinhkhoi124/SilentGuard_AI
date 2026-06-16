import json
import os
import hashlib
from datetime import datetime, timezone
import firebase_admin
from firebase_admin import auth as fb_auth, credentials
from fastapi import Depends, HTTPException, Header, status, Request
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

async def get_or_create_user(firebase_uid: str, email: str = None, name: str = None, invite_code: str = None) -> dict:
    """
    Find or provision a user in users table by firebase_uid.
    Ref: Section 3 Auth Flow - just-in-time provisioning
    """
    try:
        response = supabase.table("users").select("*").eq("firebase_uid", firebase_uid).execute()
        if response.data and len(response.data) > 0:
            return response.data[0]
        
        # Check invite code if provided
        household_id_to_join = None
        invite_record = None
        if invite_code:
            invite_res = supabase.table("household_invites").select("*").eq("code", invite_code).execute()
            if not invite_res.data or len(invite_res.data) == 0:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"error": {"code": "INVALID_INVITE_CODE", "message": "Mã mời không tồn tại"}}
                )
            invite_record = invite_res.data[0]
            
            # Check used_at and expires_at
            used_at = invite_record.get("used_at")
            expires_at_str = invite_record.get("expires_at")
            if expires_at_str:
                # Parse timestamp (handle timezone Z or +00:00)
                expires_at = datetime.fromisoformat(expires_at_str.replace("Z", "+00:00"))
            else:
                expires_at = datetime.now(timezone.utc)
                
            if used_at is not None or expires_at < datetime.now(timezone.utc):
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"error": {"code": "INVALID_INVITE_CODE", "message": "Mã mời đã được sử dụng hoặc hết hạn"}}
                )
            
            household_id_to_join = invite_record.get("household_id")

        # Provision new user
        new_user = {
            "firebase_uid": firebase_uid,
            "email": email,
            "full_name": name,
            "role": "family"
        }
        insert_response = supabase.table("users").insert(new_user).execute()
        if not insert_response.data or len(insert_response.data) == 0:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": "Failed to create user"}}
            )
        user = insert_response.data[0]
        user_uuid = user.get("id")

        # Handle household creation or joining
        if household_id_to_join:
            # Join existing household
            supabase.table("household_members").insert({
                "household_id": household_id_to_join,
                "user_id": user_uuid,
                "role": "member"
            }).execute()
            
            # Mark invite as used
            supabase.table("household_invites").update({
                "used_at": datetime.now(timezone.utc).isoformat(),
                "used_by": user_uuid
            }).eq("id", invite_record["id"]).execute()
        else:
            # Create a new household with placeholder elderly_name
            h_res = supabase.table("households").insert({
                "owner_user_id": user_uuid,
                "elderly_name": ""
            }).execute()
            if h_res.data and len(h_res.data) > 0:
                new_h = h_res.data[0]
                # Insert household owner member
                supabase.table("household_members").insert({
                    "household_id": new_h["id"],
                    "user_id": user_uuid,
                    "role": "owner"
                }).execute()

        return user
    except HTTPException as he:
        raise he
    except Exception as e:
        print(f"Error in get_or_create_user: {e}")
        # Development fallback
        fallback_user = {"id": "mock-uuid-user", "firebase_uid": firebase_uid, "email": email, "full_name": name}
        return fallback_user

async def get_current_user(
    authorization: str = Header(...),
    x_invite_code: str = Header(None, alias="X-Invite-Code")
) -> dict:
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
    user = await get_or_create_user(firebase_uid, decoded.get("email"), decoded.get("name"), x_invite_code)
    return user

def require_household_role(owner_only: bool = False):
    """
    FastAPI dependency factory to verify household access.
    """
    async def dependency(
        request: Request,
        current_user: dict = Depends(get_current_user)
    ) -> dict:
        # 1. Resolve household_id from path or query
        household_id = request.path_params.get("household_id")
        if not household_id:
            household_id = request.query_params.get("household_id")
        
        # 2. Resolve from body if still not found
        if not household_id:
            try:
                body_bytes = await request.body()
                async def receive():
                    return {"type": "http.request", "body": body_bytes, "more_body": False}
                request._receive = receive
                if body_bytes:
                    body = json.loads(body_bytes)
                    if isinstance(body, dict):
                        household_id = body.get("household_id")
            except Exception:
                pass
        
        user_id = current_user.get("id")
        
        # 3. Fallback: look up user's active household
        if not household_id:
            try:
                res = supabase.table("household_members").select("household_id").eq("user_id", user_id).execute()
                if res.data and len(res.data) > 0:
                    household_id = res.data[0]["household_id"]
            except Exception as e:
                print(f"Error resolving household_id for user: {e}")
                
        if not household_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"error": {"code": "FORBIDDEN", "message": "Bạn không thuộc về hộ gia đình nào"}}
            )
            
        # 4. Verify access
        try:
            res = supabase.table("household_members").select("*").eq("household_id", household_id).eq("user_id", user_id).execute()
            if not res.data or len(res.data) == 0:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={"error": {"code": "FORBIDDEN", "message": "Bạn không có quyền truy cập thông tin gia đình này"}}
                )
            
            member_info = res.data[0]
            if owner_only and member_info.get("role") != "owner":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail={"error": {"code": "FORBIDDEN", "message": "Yêu cầu quyền chủ hộ (owner)"}}
                )
            
            # Attach for convenience
            request.state.household_id = household_id
            request.state.household_role = member_info.get("role")
            
            return member_info
        except HTTPException as he:
            raise he
        except Exception as e:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail={"error": {"code": "DATABASE_ERROR", "message": f"Database verification error: {str(e)}"}}
            )
    return dependency

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
        if not response.data or len(response.data) == 0 or response.data[0].get("deleted_at") is not None:
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
