from __future__ import annotations

from pydantic import BaseModel, Field


class CreateMediaIn(BaseModel):
    mime: str = Field(..., description="e.g. image/jpeg, image/png")
    filename: str | None = Field(default=None, description="optional original filename")


class MediaOut(BaseModel):
    id: str
    ownerUserId: str
    storageKey: str
    mime: str
    createdAt: str | None = None


class CreateMediaOut(MediaOut):
    uploadUrl: str
    expiresIn: int
