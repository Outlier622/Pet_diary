from __future__ import annotations

import os
import uuid
import boto3
from botocore.config import Config

from app.core.config import settings


def _make_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


_s3 = _make_s3_client()


def build_storage_key(user_id: str, filename: str | None = None) -> str:
    ext = ""
    if filename and "." in filename:
        ext = "." + filename.rsplit(".", 1)[-1].strip().lower()
    return f"{user_id}/{uuid.uuid4().hex}{ext}"


def presign_put_object(storage_key: str, mime: str, expires_in: int = 900) -> str:
    return _s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={
            "Bucket": settings.s3_bucket,
            "Key": storage_key,
            "ContentType": mime,
        },
        ExpiresIn=expires_in,
    )
