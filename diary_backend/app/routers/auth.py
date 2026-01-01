from fastapi import APIRouter, Request, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.config import settings
from app.db.deps import get_db
from app.db.models import User, WhitelistEmail
from app.schemas.common import Envelope, Meta
from app.schemas.auth import RegisterIn, LoginIn, AuthOut
from app.core.errors import AppError
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    get_current_user,
)

router = APIRouter()


@router.post("/auth/register")
async def register(
    inp: RegisterIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    allowed = [e.lower() for e in settings.allowed_register_emails]
    if allowed and inp.email.lower() not in allowed:
        raise AppError(code="NOT_ALLOWED", message="Email not in allowlist", status=403)

    existing = await db.execute(select(User).where(User.email == inp.email))
    res = await db.execute(select(User).where(User.email == inp.email))
    if res.scalar_one_or_none() is not None:
        raise AppError(code="EMAIL_TAKEN", message="Email already registered", status=409)

    user = User(email=inp.email, password_hash=hash_password(inp.password))
    db.add(user)
    await db.commit()
    await db.refresh(user)

    token = create_access_token(user.id)
    return Envelope(
        data=AuthOut(accessToken=token).model_dump(),
        meta=Meta(requestId=rid),
        error=None,
    )



@router.post("/auth/login")
async def login(
    inp: LoginIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    res = await db.execute(select(User).where(User.email == inp.email))
    user = res.scalar_one_or_none()
    if user is None or not verify_password(inp.password, user.password_hash):
        raise AppError(code="INVALID_CREDENTIALS", message="Invalid email or password", status=401)

    token = create_access_token(user.id)
    return Envelope(
        data=AuthOut(accessToken=token).model_dump(),
        meta=Meta(requestId=rid),
        error=None,
    )


@router.get("/auth/me")
async def me(
    request: Request,
    user: User = Depends(get_current_user),
):
    rid = getattr(request.state, "request_id", "unknown")

    return Envelope(
        data={
            "id": str(user.id),
            "email": user.email,
            "createdAt": user.created_at.isoformat() if getattr(user, "created_at", None) else None,
        },
        meta=Meta(requestId=rid),
        error=None,
    )
