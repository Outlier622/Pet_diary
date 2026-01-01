from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.db.models import Media
from app.schemas.common import Envelope, Meta
from app.schemas.media import CreateMediaIn, CreateMediaOut, MediaOut
from app.core.deps import get_current_user_id
from app.core.errors import AppError
from app.core.s3 import build_storage_key, presign_put_object

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


async def get_media_or_404(db: AsyncSession, user_id: str, media_id: str) -> Media:
    res = await db.execute(
        select(Media).where(Media.id == str(media_id), Media.owner_user_id == str(user_id))
    )
    m = res.scalar_one_or_none()
    if not m:
        raise AppError(code="NOT_FOUND", message="Media not found", status=404)
    return m


@router.post("/media")
async def create_media(
    inp: CreateMediaIn,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    storage_key = build_storage_key(user_id=user_id, filename=inp.filename)
    upload_url = presign_put_object(storage_key=storage_key, mime=inp.mime, expires_in=900)

    m = Media(
        owner_user_id=str(user_id),
        storage_key=storage_key,
        mime=inp.mime,
    )
    db.add(m)
    await db.commit()
    await db.refresh(m)

    out = CreateMediaOut(
        **to_media_out(m).model_dump(),
        uploadUrl=upload_url,
        expiresIn=900,
    )
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)


@router.get("/media/{media_id}")
async def get_media(
    media_id: str,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    m = await get_media_or_404(db, user_id, media_id)
    out = to_media_out(m)
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)
