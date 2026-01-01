from pydantic import BaseModel
from typing import Any, Optional

class ErrorBody(BaseModel):
    code: str
    message: str
    details: Optional[dict[str, Any]] = None

class Meta(BaseModel):
    requestId: str
    nextCursor: str | None = None
    hasMore: bool | None = None

class Envelope(BaseModel):
    data: Any | None
    meta: Meta
    error: ErrorBody | None
