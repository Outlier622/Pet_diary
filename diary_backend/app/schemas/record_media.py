from pydantic import BaseModel


class AttachMediaIn(BaseModel):
    mediaId: str
