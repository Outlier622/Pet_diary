from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from app.routers.whitelist import router as whitelist_router

from app.core.config import settings
from app.core.middleware import RequestIdMiddleware
from app.core.errors import AppError
from app.schemas.common import Envelope, Meta, ErrorBody
from app.core.logging import get_logger
from app.db.session import init_db
from app.routers import record_media
from app.routers.health import router as health_router
from app.routers.auth import router as auth_router
from app.routers.pets import router as pets_router
from app.routers.records import router as records_router
from app.routers.media import router as media_router
from app.routers.users import router as users_router

log = get_logger()

app = FastAPI(title="Pet Growth Diary Backend", version="0.1.0")

app.add_middleware(RequestIdMiddleware)

@app.on_event("startup")
async def on_startup():
    await init_db()
    log.info("startup complete")

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    rid = getattr(request.state, "request_id", "unknown")
    body = Envelope(
        data=None,
        meta=Meta(requestId=rid),
        error=ErrorBody(code=exc.code, message=exc.message, details=exc.details),
    )
    return JSONResponse(status_code=exc.status, content=body.model_dump())

@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception):
    rid = getattr(request.state, "request_id", "unknown")
    log.exception("unhandled error", extra={"requestId": rid})
    body = Envelope(
        data=None,
        meta=Meta(requestId=rid),
        error=ErrorBody(code="INTERNAL_ERROR", message="Internal server error"),
    )
    return JSONResponse(status_code=500, content=body.model_dump())

@app.exception_handler(AppError)
async def app_error_handler(request: Request, exc: AppError):
    rid = getattr(request.state, "request_id", "unknown")

    return JSONResponse(
        status_code=getattr(exc, "status", 400),
        content=Envelope(
            data=None,
            meta=Meta(requestId=rid),
            error={
                "code": getattr(exc, "code", "APP_ERROR"),
                "message": getattr(exc, "message", "Application error"),
                "details": getattr(exc, "details", None),
            },
        ).model_dump(),
    )

@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    rid = getattr(request.state, "request_id", "unknown")

    return JSONResponse(
        status_code=422,
        content=Envelope(
            data=None,
            meta=Meta(requestId=rid),
            error={
                "code": "VALIDATION_ERROR",
                "message": "Validation error",
                "details": {"errors": exc.errors()},

            },
        ).model_dump(),
    )

@app.exception_handler(StarletteHTTPException)
async def http_error_handler(request: Request, exc: StarletteHTTPException):
    rid = getattr(request.state, "request_id", "unknown")

    details = exc.detail if isinstance(exc.detail, (dict, list)) else {"detail": exc.detail}
    return JSONResponse(
        status_code=exc.status_code,
        content=Envelope(
            data=None,
            meta=Meta(requestId=rid),
            error={
                "code": f"HTTP_{exc.status_code}",
                "message": "HTTP error",
                "details": details,
            },
        ).model_dump(),
    )

@app.exception_handler(Exception)
async def unhandled_error_handler(request: Request, exc: Exception):
    rid = getattr(request.state, "request_id", "unknown")

    return JSONResponse(
        status_code=500,
        content=Envelope(
            data=None,
            meta=Meta(requestId=rid),
            error={
                "code": "INTERNAL_ERROR",
                "message": "Internal server error",
                "details": None,
            },
        ).model_dump(),
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    rid = getattr(request.state, "request_id", None)
    log.exception("Unhandled exception")

    return JSONResponse(
        status_code=500,
        content=Envelope(
            data=None,
            meta=Meta(requestId=rid),
            error={
                "code": "INTERNAL_ERROR",
                "message": "Internal server error",
                "details": None,
            },
        ).model_dump(),
    )


app.include_router(whitelist_router, prefix=settings.api_prefix, tags=["whitelist"])
app.include_router(health_router, prefix=settings.api_prefix, tags=["health"])
app.include_router(auth_router, prefix=settings.api_prefix, tags=["auth"])
app.include_router(pets_router, prefix=settings.api_prefix, tags=["pets"])
app.include_router(records_router, prefix=settings.api_prefix, tags=["records"])
app.include_router(media_router, prefix=settings.api_prefix, tags=["media"])
app.include_router(users_router, prefix=settings.api_prefix,tags=["users"])
app.include_router(record_media.router, prefix=settings.api_prefix, tags=["record_media"])
