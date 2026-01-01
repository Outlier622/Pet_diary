from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from typing import AsyncGenerator
from app.core.config import settings

engine = create_async_engine(
    settings.database_url,
    echo=False,
    future=True,
)

SessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
)


async def get_db() -> AsyncSession:
    async with SessionLocal() as db:
        yield db


async def init_db() -> None:
    """
    Keep this because app/main.py calls it on startup.
    Creates tables if they don't exist.
    """
    # 延迟 import，避免循环依赖
    from app.db.base import Base  # Base = declarative_base()

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
