import uuid
import boto3
from botocore.client import Config
from app.core.config import settings

def make_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=settings.s3_endpoint_url,
        aws_access_key_id=settings.s3_access_key,
        aws_secret_access_key=settings.s3_secret_key,
        region_name=settings.s3_region,
        config=Config(signature_version="s3v4"),
    )

def ensure_bucket_exists():
    s3 = make_s3_client()
    buckets = s3.list_buckets().get("Buckets", [])
    if not any(b["Name"] == settings.s3_bucket for b in buckets):
        s3.create_bucket(Bucket=settings.s3_bucket)

def new_storage_key(owner_user_id: str) -> str:
    return f"{owner_user_id}/{uuid.uuid4()}"

def presign_put_url(storage_key: str, mime: str, expires_sec: int = 900) -> str:
    s3 = make_s3_client()
    ensure_bucket_exists()
    return s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": settings.s3_bucket, "Key": storage_key, "ContentType": mime},
        ExpiresIn=expires_sec,
    )
