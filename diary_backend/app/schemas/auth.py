from pydantic import BaseModel, EmailStr, constr

Password = constr(min_length=8, max_length=72)

class RegisterIn(BaseModel):
    email: EmailStr
    password: str

class LoginIn(BaseModel):
    email: EmailStr
    password: str

class AuthOut(BaseModel):
    accessToken: str
