from pydantic import BaseModel, Field
from typing import Optional

class CreatePetIn(BaseModel):
    name: str = Field(min_length=1)
    species: str = Field(min_length=1)
    breed: Optional[str] = None
    birthday: Optional[str] = None

class PetOut(BaseModel):
    id: str
    ownerUserId: str
    name: str
    species: str
    breed: Optional[str] = None
    birthday: Optional[str] = None
    createdAt: Optional[str] = None

    model_config = {"from_attributes": True}

class UpdatePetIn(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1)
    species: Optional[str] = Field(default=None, min_length=1)
    breed: Optional[str] = None
    birthday: Optional[str] = None
