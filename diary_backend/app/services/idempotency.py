import hashlib
import json
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.db.models import IdempotencyKey

def _hash_request(payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()

async def get_idempotent_response(
    db: AsyncSession,
    owner_user_id: str,
    key: str,
) -> dict | None:
    res = await db.execute(
        select(IdempotencyKey).where(
            IdempotencyKey.owner_user_id == owner_user_id,
            IdempotencyKey.key == key,
        )
    )
    row = res.scalar_one_or_none()
    if row is None:
        return None
    return row.response_json

async def save_idempotent_response(
    db: AsyncSession,
    owner_user_id: str,
    key: str,
    request_payload: dict,
    response_json: dict,
) -> None:
    idem = IdempotencyKey(
        owner_user_id=owner_user_id,
        key=key,
        request_hash=_hash_request(request_payload),
        response_json=response_json,
    )
    db.add(idem)
    try:
        await db.commit()
    except Exception:
        await db.rollback()
        # If a race inserts same key, caller should re-fetch
        raise AppError(code="IDEMPOTENCY_CONFLICT", message="Idempotency key conflict", status=409)
