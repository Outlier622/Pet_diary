import hashlib
import json
from fastapi import Request, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.models import IdempotencyKey
from app.core.deps import get_current_user_id
from app.db.session import get_db
from app.core.errors import AppError


async def enforce_idempotency(
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    key = request.headers.get("Idempotency-Key")
    if not key:
        return None

    body = await request.body()
    body_hash = hashlib.sha256(body).hexdigest()

    res = await db.execute(
        select(IdempotencyKey).where(
            IdempotencyKey.owner_user_id == user_id,
            IdempotencyKey.key == key,
        )
    )
    row = res.scalar_one_or_none()

    if row:
        if row.request_hash != body_hash:
            raise AppError(
                code="IDEMPOTENCY_CONFLICT",
                message="Same key with different payload",
                status=409,
            )
        return row.response_json

    return {
        "key": key,
        "hash": body_hash,
    }
