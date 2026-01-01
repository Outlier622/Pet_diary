from fastapi import APIRouter, Depends, Request, Header
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.common import Envelope, Meta
from app.core.errors import AppError
from app.core.config import settings
from app.db.session import SessionLocal
from app.db.models import WhitelistEmail
from app.schemas.whitelist import WhitelistAddIn, WhitelistOut

router = APIRouter()

async def get_db() -> AsyncSession:
    async with SessionLocal() as db:
        yield db

def require_admin(x_admin_key: str | None):
    # 最小可用的“管理员保护”：用一个 header key 控制（你后面再换成真正 RBAC）
    if not getattr(settings, "admin_key", None):
        # 没配置就默认拒绝，避免裸奔
        raise AppError(code="FORBIDDEN", message="Admin key not configured", status=403)
    if x_admin_key != settings.admin_key:
        raise AppError(code="FORBIDDEN", message="Forbidden", status=403)

@router.post("/whitelist", response_model=None)
async def add_whitelist(
    inp: WhitelistAddIn,
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_admin_key: str | None = Header(default=None, alias="X-Admin-Key"),
):
    require_admin(x_admin_key)
    rid = getattr(request.state, "request_id", "unknown")

    existing = await db.execute(select(WhitelistEmail).where(WhitelistEmail.email == inp.email))
    if existing.scalar_one_or_none() is not None:
        raise AppError(code="ALREADY_EXISTS", message="Email already in whitelist", status=409)

    row = WhitelistEmail(email=inp.email)
    db.add(row)
    await db.commit()
    await db.refresh(row)

    out = WhitelistOut(
        id=str(row.id),
        email=row.email,
        createdAt=row.created_at.isoformat() if getattr(row, "created_at", None) else None,
    )
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)

@router.get("/whitelist", response_model=None)
async def list_whitelist(
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_admin_key: str | None = Header(default=None, alias="X-Admin-Key"),
):
    require_admin(x_admin_key)
    rid = getattr(request.state, "request_id", "unknown")

    res = await db.execute(select(WhitelistEmail).order_by(WhitelistEmail.created_at.desc()))
    rows = res.scalars().all()

    data = [
        WhitelistOut(
            id=str(r.id),
            email=r.email,
            createdAt=r.created_at.isoformat() if getattr(r, "created_at", None) else None,
        ).model_dump()
        for r in rows
    ]
    return Envelope(data=data, meta=Meta(requestId=rid), error=None)

@router.delete("/whitelist/{email}", response_model=None)
async def remove_whitelist(
    email: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
    x_admin_key: str | None = Header(default=None, alias="X-Admin-Key"),
):
    require_admin(x_admin_key)
    rid = getattr(request.state, "request_id", "unknown")

    await db.execute(delete(WhitelistEmail).where(WhitelistEmail.email == email))
    await db.commit()
    return Envelope(data={"ok": True}, meta=Meta(requestId=rid), error=None)
