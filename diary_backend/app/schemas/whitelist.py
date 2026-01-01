from pydantic import BaseModel, EmailStr


class WhitelistAddIn(BaseModel):
    email: EmailStr


class WhitelistOut(BaseModel):
    id: str
    email: EmailStr
    createdAt: str | None = None
