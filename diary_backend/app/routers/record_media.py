from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.db.models import Record, Media, RecordMedia
from app.schemas.common import Envelope, Meta
from app.schemas.media import MediaOut
from app.schemas.record_media import AttachMediaIn

from app.core.deps import get_current_user_id
from app.core.errors import AppError

router = APIRouter()


async def get_db() -> AsyncSession:
    async with SessionLocal() as db:
        yield db


def to_media_out(m: Media) -> MediaOut:
    return MediaOut(
        id=str(m.id),
        ownerUserId=str(m.owner_user_id),
        storageKey=m.storage_key,
        mime=m.mime,
        createdAt=m.created_at.isoformat() if getattr(m, "created_at", None) else None,
    )


async def get_record_or_404(db: AsyncSession, user_id: str, record_id: str) -> Record:
    res = await db.execute(
        select(Record).where(Record.id == str(record_id), Record.owner_user_id == str(user_id))
    )
    rec = res.scalar_one_or_none()
    if not rec:
        raise AppError(code="NOT_FOUND", message="Record not found", status=404)
    return rec


async def get_media_or_404(db: AsyncSession, user_id: str, media_id: str) -> Media:
    res = await db.execute(
        select(Media).where(Media.id == str(media_id), Media.owner_user_id == str(user_id))
    )
    m = res.scalar_one_or_none()
    if not m:
        raise AppError(code="NOT_FOUND", message="Media not found", status=404)
    return m


@router.post("/records/{record_id}/media")
async def attach_media_to_record(
    record_id: str,
    inp: AttachMediaIn,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    await get_record_or_404(db, user_id, record_id)
    await get_media_or_404(db, user_id, inp.mediaId)

    exists = await db.execute(
        select(RecordMedia).where(
            RecordMedia.record_id == str(record_id),
            RecordMedia.media_id == str(inp.mediaId),
        )
    )
    if exists.scalar_one_or_none() is not None:
        return Envelope(data={"ok": True}, meta=Meta(requestId=rid), error=None)

    rm = RecordMedia(record_id=str(record_id), media_id=str(inp.mediaId))
    db.add(rm)
    await db.commit()

    return Envelope(data={"ok": True}, meta=Meta(requestId=rid), error=None)


@router.get("/records/{record_id}/media")
async def list_record_media(
    record_id: str,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    await get_record_or_404(db, user_id, record_id)

    stmt = (
        select(Media)
        .join(RecordMedia, RecordMedia.media_id == Media.id)
        .where(RecordMedia.record_id == str(record_id))
        .order_by(Media.created_at.desc())
    )
    res = await db.execute(stmt)
    items = [to_media_out(m).model_dump() for m in res.scalars().all()]

    return Envelope(data={"items": items}, meta=Meta(requestId=rid), error=None)
