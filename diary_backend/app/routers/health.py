from fastapi import APIRouter, Request
from app.schemas.common import Envelope, Meta

router = APIRouter()

@router.get("/health")
async def health(request: Request):
    rid = getattr(request.state, "request_id", "unknown")
    return Envelope(data={"ok": True}, meta=Meta(requestId=rid), error=None)
