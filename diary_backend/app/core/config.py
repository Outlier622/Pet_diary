from pydantic_settings import BaseSettings
from typing import List
from pydantic import Field

class Settings(BaseSettings):
    app_env: str = "dev"
    api_prefix: str = "/api/v1"
    admin_key: str = "dev-admin-key"

    jwt_secret: str = "change-me-super-secret"
    jwt_alg: str = "HS256"
    access_token_expire_min: int = 60

    database_url: str = "postgresql+asyncpg://diary:diary@localhost:5432/diary"
    redis_url: str = "redis://localhost:6379/0"

    s3_endpoint_url: str = "http://localhost:9000"
    s3_access_key: str = "minio"
    s3_secret_key: str = "minio123"
    s3_bucket: str = "diary-media"
    s3_region: str = "us-east-1"

    allowed_register_emails: List[str] = Field(default_factory=list)
    class Config:
        env_file = ".env"
        case_sensitive = False

settings = Settings()
