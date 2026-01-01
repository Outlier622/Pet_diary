from fastapi import APIRouter, Request, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import SessionLocal
from app.db.models import Pet
from app.schemas.common import Envelope, Meta
from app.schemas.pets import PetOut, CreatePetIn, UpdatePetIn

from app.core.deps import get_current_user_id
from app.core.errors import AppError

router = APIRouter()


async def get_db() -> AsyncSession:
    async with SessionLocal() as db:
        yield db


def to_pet_out(pet: Pet) -> PetOut:
    return PetOut(
        id=str(pet.id),
        ownerUserId=str(pet.owner_user_id),
        name=pet.name,
        species=pet.species,
        breed=getattr(pet, "breed", None),
        birthday=getattr(pet, "birthday", None),
        createdAt=pet.created_at.isoformat() if getattr(pet, "created_at", None) else None,
    )


async def get_pet_or_404(db: AsyncSession, user_id: str, pet_id: str) -> Pet:
    res = await db.execute(
        select(Pet).where(Pet.id == pet_id, Pet.owner_user_id == str(user_id))
    )
    pet = res.scalar_one_or_none()
    if not pet:
        raise AppError(code="NOT_FOUND", message="Pet not found", status=404)
    return pet


@router.post("/pets")
async def create_pet(
    inp: CreatePetIn,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    pet = Pet(
        owner_user_id=str(user_id),
        name=inp.name,
        species=inp.species,
        breed=inp.breed,
        birthday=inp.birthday,
    )
    db.add(pet)
    await db.commit()
    await db.refresh(pet)

    out = to_pet_out(pet)
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)


@router.get("/pets")
async def list_pets(
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    res = await db.execute(
        select(Pet)
        .where(Pet.owner_user_id == str(user_id))
        .order_by(Pet.created_at.desc())
    )
    pets = res.scalars().all()

    items = [to_pet_out(p).model_dump() for p in pets]
    return Envelope(data={"items": items}, meta=Meta(requestId=rid), error=None)


@router.get("/pets/{pet_id}")
async def get_pet(
    pet_id: str,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    pet = await get_pet_or_404(db, user_id, pet_id)
    out = to_pet_out(pet)
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)


@router.patch("/pets/{pet_id}")
async def update_pet(
    pet_id: str,
    inp: UpdatePetIn,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    pet = await get_pet_or_404(db, user_id, pet_id)

    payload = inp.model_dump(exclude_unset=True)
    if "name" in payload:
        pet.name = payload["name"]
    if "species" in payload:
        pet.species = payload["species"]
    if "breed" in payload:
        pet.breed = payload["breed"]
    if "birthday" in payload:
        pet.birthday = payload["birthday"]

    await db.commit()
    await db.refresh(pet)

    out = to_pet_out(pet)
    return Envelope(data=out.model_dump(), meta=Meta(requestId=rid), error=None)


@router.delete("/pets/{pet_id}")
async def delete_pet(
    pet_id: str,
    request: Request,
    user_id: str = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    rid = getattr(request.state, "request_id", "unknown")

    pet = await get_pet_or_404(db, user_id, pet_id)

    await db.delete(pet)
    await db.commit()

    return Envelope(data={"ok": True}, meta=Meta(requestId=rid), error=None)
