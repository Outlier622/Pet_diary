from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.common import Envelope, Meta
from app.schemas.users import UserOut, UpdateProfileIn, UpdatePasswordIn
from app.db.models import User

from sqlalchemy import select
from app.db.deps import get_db

from app.core.security import get_current_user, verify_password, hash_password

router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me")
async def get_me(
    request: Request,
    user: User = Depends(get_current_user),
):
    rid = getattr(request.state, "request_id", "unknown")

    out = UserOut(
    id=str(user.id),
    email=user.email,
    displayName=getattr(user, "display_name", None),
    bio=getattr(user, "bio", None),
    avatarUrl=getattr(user, "avatar_url", None),
    createdAt=user.created_at.isoformat() if getattr(user, "created_at", None) else None,
    )


    return Envelope(
        data=out.model_dump(),
        meta=Meta(requestId=rid),
        error=None,
    )


@router.patch("/me")
async def update_profile(
    inp: UpdateProfileIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rid = getattr(request.state, "request_id", "unknown")

    update_data = inp.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        setattr(user, field, value)

    await db.commit()
    await db.refresh(user)

    out = UserOut.model_validate(user)

    return Envelope(
        data=out.model_dump(),
        meta=Meta(requestId=rid),
        error=None,
    )

@router.patch("/me/password")
async def update_password(
    inp: UpdatePasswordIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
):
    rid = getattr(request.state, "request_id", "unknown")

    res = await db.execute(select(User).where(User.id == user.id))
    db_user = res.scalar_one_or_none()
    if db_user is None:
        raise AppError(code="UNAUTHORIZED", message="User not found", status=401)

    if not verify_password(inp.current_password, db_user.password_hash):
        raise AppError(code="INVALID_CREDENTIALS", message="Current password is incorrect", status=401)

    db_user.password_hash = hash_password(inp.new_password)
    db.add(db_user)
    await db.commit()

    return Envelope(
        data={"ok": True},
        meta=Meta(requestId=rid),
        error=None,
    )
