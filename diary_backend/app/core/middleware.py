import uuid
import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from app.core.logging import get_logger

log = get_logger()

class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        rid = request.headers.get("X-Request-Id") or str(uuid.uuid4())
        request.state.request_id = rid

        start = time.time()
        try:
            response = await call_next(request)
        finally:
            dur_ms = int((time.time() - start) * 1000)
            log.info(
                "request",
                extra={
                    "requestId": rid,
                    "method": request.method,
                    "path": request.url.path,
                    "durationMs": dur_ms,
                },
            )

        response.headers["X-Request-Id"] = rid
        return response
