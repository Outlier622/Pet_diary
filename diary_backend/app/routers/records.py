from __future__ import annotations

from fastapi import APIRouter, Depends, Request, Query, Header
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import hashlib
import json

from app.db.session import SessionLocal
from app.db.models import Record, Pet, IdempotencyKey
from app.schemas.common import Envelope, Meta
from app.schemas.records import CreateRecordIn, UpdateRecordIn, RecordOut
from app.core.deps import get_current_user_id
from app.core.errors import AppError

router = APIRouter()


async def get_db() -> AsyncSession:
    async with SessionLocal() as db:
        yield db


def to_record_out(r: Record) -> RecordOut:
    return RecordOut(
        id=str(r.id),
        ownerUserId=str(r.owner_user_id),
        petId=str(r.pet_id),
        type=r.type,
        occurredAt=r.occurred_at.isoformat() if r.occurred_at else None,
        payload=r.payload or {},
        createdAt=r.created_at.isoformat() if r.created_at else None,
    )


async def ensure_pet_owned(db: AsyncSession, user_id: str, pet_id: str) -> None:
    res = await db.execute(
        select(Pet.id).where(
            Pet.id == str(pet_id),
            Pet.owner_user_id == str(user_id),
        )
    )
    if res.scalar_one_or_none() is None:
        raise AppError(code="NOT_FOUND", message="Pet not found", status=404)


@router.post("/records")
async def create_record(
    inp: CreateRecordIn,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    rid = getattr(request.state, "request_id", "unknown")

    # ---------- 幂等：命中直接返回 ----------
    if idempotency_key:
        res = await db.execute(
            select(IdempotencyKey).where(
                IdempotencyKey.owner_user_id == str(user_id),
                IdempotencyKey.key == idempotency_key,
            )
        )
        idem = res.scalar_one_or_none()
        if idem:
            return Envelope(
                data=idem.response_json.get("data"),
                meta=Meta(requestId=rid),
                error=None,
            )

    # ---------- 正常创建 ----------
    await ensure_pet_owned(db, user_id, inp.petId)

    rec = Record(
        owner_user_id=str(user_id),
        pet_id=str(inp.petId),
        type=inp.type,
        occurred_at=inp.occurredAt,
        payload=inp.payload or {},
    )
    db.add(rec)
    await db.commit()
    await db.refresh(rec)

    out = to_record_out(rec)
    response_data = out.model_dump()

    # ---------- 保存幂等结果 ----------
    if idempotency_key:
        request_hash = hashlib.sha256(
            json.dumps(inp.model_dump(), sort_keys=True).encode()
        ).hexdigest()

        db.add(
            IdempotencyKey(
                owner_user_id=str(user_id),
                key=idempotency_key,
                request_hash=request_hash,
                response_json={"data": response_data},
            )
        )
        await db.commit()

    return Envelope(
        data=response_data,
        meta=Meta(requestId=rid),
        error=None,
    )


@router.get("/records")
async def list_records(
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
    petId: str | None = Query(default=None),
    recordType: str | None = Query(default=None, alias="type"),
    limit: int = Query(default=50, ge=1, le=200),
):
    rid = getattr(request.state, "request_id", "unknown")

    stmt = select(Record).where(Record.owner_user_id == str(user_id))

    if petId:
        stmt = stmt.where(Record.pet_id == str(petId))
    if recordType:
        stmt = stmt.where(Record.type == recordType)

    stmt = stmt.order_by(Record.occurred_at.desc()).limit(limit)

    res = await db.execute(stmt)
    items = [to_record_out(r).model_dump() for r in res.scalars().all()]

    return Envelope(
        data={"items": items},
        meta=Meta(requestId=rid),
        error=None,
    )
