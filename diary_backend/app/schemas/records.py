from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, Field, ConfigDict


class CreateRecordIn(BaseModel):
    petId: str = Field(..., min_length=1)
    type: str = Field(..., min_length=1)
    occurredAt: datetime
    payload: dict = Field(default_factory=dict)


class UpdateRecordIn(BaseModel):
    occurredAt: datetime | None = None
    payload: dict | None = None


class RecordOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    ownerUserId: str
    petId: str
    type: str
    occurredAt: str
    payload: dict
    createdAt: str | None = None
