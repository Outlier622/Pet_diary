from typing import Optional
from pydantic import BaseModel, Field, field_validator, ConfigDict

class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    email: str
    displayName: Optional[str] = None
    bio: Optional[str] = None
    avatarUrl: Optional[str] = None
    createdAt: Optional[str] = None

class UpdateProfileIn(BaseModel):
    displayName: Optional[str] = Field(default=None, max_length=50)
    bio: Optional[str] = Field(default=None, max_length=300)
    avatarUrl: Optional[str] = Field(default=None, max_length=2048)

class UpdatePasswordIn(BaseModel):
    current_password: str
    new_password: str

    @field_validator("current_password", "new_password")
    @classmethod
    def password_not_empty(cls, v: str) -> str:
        v = (v or "").strip()
        if not v:
            raise ValueError("Password cannot be empty")
        return v

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")

        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password too long (bcrypt supports up to 72 bytes). Please use a shorter password.")
        return v