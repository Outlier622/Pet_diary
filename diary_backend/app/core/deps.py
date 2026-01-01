from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.core.security import decode_token
from app.core.errors import AppError

bearer = HTTPBearer(auto_error=False)

def get_current_user_id(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
) -> str:
    if creds is None or not creds.credentials:
        raise AppError(code="UNAUTHORIZED", message="Missing Bearer token", status=401)

    token = creds.credentials
    payload = decode_token(token)

    user_id = payload.get("sub")
    if not user_id:
        raise AppError(code="UNAUTHORIZED", message="Invalid token payload", status=401)

    return str(user_id)
