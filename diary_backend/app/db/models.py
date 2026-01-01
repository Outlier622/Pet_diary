import uuid
from sqlalchemy import String, DateTime, ForeignKey, Index, JSON, func
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

def uuid4() -> str:
    return str(uuid.uuid4())

class User(Base):
    __tablename__ = "users"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())

    display_name: Mapped[str | None] = mapped_column(String, nullable=True)
    avatar_url: Mapped[str | None] = mapped_column(String, nullable=True)
    bio: Mapped[str | None] = mapped_column(String, nullable=True)


class Pet(Base):
    __tablename__ = "pets"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    owner_user_id: Mapped[str] = mapped_column(String, ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String)
    species: Mapped[str] = mapped_column(String)
    breed: Mapped[str | None] = mapped_column(String, nullable=True)
    birthday: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())

class Record(Base):
    __tablename__ = "records"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    owner_user_id: Mapped[str] = mapped_column(String, index=True)
    pet_id: Mapped[str] = mapped_column(String, ForeignKey("pets.id"), index=True)
    type: Mapped[str] = mapped_column(String, index=True)
    occurred_at: Mapped[object] = mapped_column(DateTime(timezone=True), index=True)
    payload: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())

Index("idx_records_timeline", Record.owner_user_id, Record.pet_id, Record.occurred_at.desc())

class Media(Base):
    __tablename__ = "media"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    owner_user_id: Mapped[str] = mapped_column(String, index=True)
    storage_key: Mapped[str] = mapped_column(String, unique=True, index=True)
    mime: Mapped[str] = mapped_column(String)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())

class RecordMedia(Base):
    __tablename__ = "record_media"
    record_id: Mapped[str] = mapped_column(String, ForeignKey("records.id"), primary_key=True)
    media_id: Mapped[str] = mapped_column(String, ForeignKey("media.id"), primary_key=True)

class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    owner_user_id: Mapped[str] = mapped_column(String, index=True)
    key: Mapped[str] = mapped_column(String, index=True)
    request_hash: Mapped[str] = mapped_column(String)
    response_json: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())

Index("idx_idem_owner_key", IdempotencyKey.owner_user_id, IdempotencyKey.key, unique=True)

class WhitelistEmail(Base):
    __tablename__ = "whitelist_emails"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=uuid4)
    email: Mapped[str] = mapped_column(String, unique=True, index=True)
    created_at: Mapped[object] = mapped_column(DateTime(timezone=True), server_default=func.now())
