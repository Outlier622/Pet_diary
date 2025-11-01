import os, time, logging, sqlite3, struct, json, uuid
from datetime import datetime
from functools import wraps

from flask import Flask, request, jsonify, Response
from werkzeug.exceptions import HTTPException
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
from PIL import Image
import psutil

# --- inference imports ---
from predict_image import predict_single_image
from predict_breed import predict_dog_breed
from predict_cat_breed import predict_cat_breed
# -------------------------

# --- OpenTelemetry imports ---
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace.export import BatchSpanProcessor
# -----------------------------

load_dotenv()

# ====== Configs / Security ======
APP_VERSION    = os.getenv("APP_VERSION", "dev")
MODEL_REF      = os.getenv("MODEL_REF", "unknown")
APP_TOKEN      = os.getenv("APP_TOKEN", "dev-admin")
PUBLIC_API_KEY = os.getenv("PUBLIC_API_KEY", "dev-key")
API_KEY_REQUIRED = os.getenv("API_KEY_REQUIRED", "true").lower() == "true"

ALLOWED_TYPES = {"image/jpeg", "image/png"}
MAX_SIZE = 5 * 1024 * 1024  # 5MB

UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "uploads")
DB_FILE       = os.getenv("DB_FILE", "cat_dog.db")
WORKERS_URL   = os.getenv("WORKERS_URL")
OTLP_ENDPOINT = os.getenv("OTLP_ENDPOINT", "http://otel-collector:4318/v1/traces")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ====== App ======
app = Flask(__name__)
limiter = Limiter(get_remote_address, app=app, default_limits=["100/minute"])

# ====== OpenTelemetry (init AFTER app is created) ======
tp = TracerProvider()
trace.set_tracer_provider(tp)
tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT)))
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()
tracer = trace.get_tracer(__name__)

# ====== Prometheus Metrics (unified) ======
HTTP_REQ = Counter("http_requests_total", "Total HTTP requests", ["method", "path", "code"])
HTTP_LAT = Histogram("http_request_seconds", "Request latency seconds", ["method", "path"])
HTTP_ERR = Counter("http_errors_total", "Total HTTP errors", ["path", "type"])

IFQ = Gauge("inference_queue_length", "inference queue length")
CPU = Gauge("process_cpu_percent", "process cpu percent")
MEM = Gauge("process_rss_bytes", "process RSS bytes")
MODEL_READY = Gauge("model_loaded", "model loaded (0/1)")
UPTIME = Gauge("process_uptime_seconds", "process uptime seconds")

START_TS = time.time()
MODEL_LOADED = False

# ====== Utilities ======
def _json(code, obj):
    HTTP_REQ.labels(request.method, request.path, str(code)).inc()
    return jsonify(obj), code

def _bad(code, msg):
    return _json(code, {"code": code, "error": msg})

def require_admin(f):
    @wraps(f)
    def _wrap(*args, **kwargs):
        token = request.headers.get("X-Admin-Token", "")
        if token != APP_TOKEN:
            return _bad(401, "unauthorized")
        return f(*args, **kwargs)
    return _wrap

def require_public_key(f):
    @wraps(f)
    def _wrap(*args, **kwargs):
        if API_KEY_REQUIRED and request.path not in ("/metrics", "/livez", "/readyz", "/healthz"):
            k = request.headers.get("X-API-Key", "")
            if k != PUBLIC_API_KEY:
                return _bad(401, "unauthorized")
        return f(*args, **kwargs)
    return _wrap

def _file_guards(fs):
    if "image" not in fs:
        return 400, "no file field 'image'"
    f = fs["image"]
    if not f or not getattr(f, "mimetype", None):
        return 400, "bad file"
    if f.mimetype not in ALLOWED_TYPES:
        return 400, "bad content-type"
    f.seek(0, os.SEEK_END)
    sz = f.tell()
    f.seek(0)
    if sz > MAX_SIZE:
        return 400, "file too large"
    return 0, "ok"

def extract_dominant_color(img_path):
    img = Image.open(img_path).convert('RGB')
    colors = img.getcolors(img.size[0] * img.size[1])
    dominant = max(colors, key=lambda tup: tup[0])
    r, g, b = dominant[1]
    if r > 200 and g > 200 and b > 200: return "White"
    if r < 50 and g < 50 and b < 50:    return "Black"
    if r > g and r > b:                 return "Red-ish"
    if g > r and g > b:                 return "Green-ish"
    if b > r and b > g:                 return "Blue-ish"
    return f"RGB({r},{g},{b})"

def init_db():
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute("""
        CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            filename TEXT,
            animal TEXT,
            breed TEXT,
            color TEXT,
            confidence REAL,
            timestamp TEXT
        )
        """)
        conn.commit()
init_db()

# ====== Hooks ======
@app.before_request
def _before():
    request._ts = time.time()
    request._rid = request.headers.get("X-Request-Id") or str(uuid.uuid4())

@app.after_request
def _after(resp):
    try:
        dur = time.time() - getattr(request, "_ts", time.time())
        HTTP_LAT.labels(request.method, request.path).observe(dur)
        HTTP_REQ.labels(request.method, request.path, str(resp.status_code)).inc()

        # process metrics
        UPTIME.set(time.time() - START_TS)
        MODEL_READY.set(1 if MODEL_LOADED else 0)
        CPU.set(psutil.Process().cpu_percent() / 100.0)
        MEM.set(psutil.Process().memory_info().rss)

        # structured access log (attach trace_id if present)
        span = trace.get_current_span()
        span_ctx = span.get_span_context() if span else None
        trace_id = f"{span_ctx.trace_id:032x}" if (span_ctx and span_ctx.trace_id) else None
        logging.getLogger("app").info(json.dumps({
            "ts": time.time(),
            "rid": getattr(request, "_rid", "-"),
            "trace_id": trace_id,
            "method": request.method,
            "path": request.path,
            "status": resp.status_code,
            "latency_ms": int(dur * 1000)
        }))
    finally:
        return resp

# ====== Health / Metrics ======
@app.get("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.get("/livez")
def livez():
    return _json(200, {"status": "alive", "version": APP_VERSION})

@app.get("/readyz")
def readyz():
    code = 200 if MODEL_LOADED else 503
    return _json(code, {"ready": code == 200, "model_ref": MODEL_REF})

@app.get("/healthz")
def healthz():
    return _json(200, {"status": "ok"})

# ====== Admin ======
@app.get("/admin/ping")
@require_admin
def admin_ping():
    return _json(200, {"ok": True})

# ====== Business APIs ======
@app.post("/classify")
@require_public_key
@limiter.limit("10/second")
def classify():
    global MODEL_LOADED
    code, msg = _file_guards(request.files)
    if code: return _bad(code, msg)

    f = request.files["image"]
    filename = datetime.now().strftime('%Y%m%d%H%M%S') + '_' + f.filename
    path = os.path.join(UPLOAD_FOLDER, filename)
    f.save(path)

    animal, conf = predict_single_image(path)
    if not animal:
        return _bad(500, "failed to analyze image")
    MODEL_LOADED = True

    breed, breed_conf = ("Unknown", 0.0)
    if animal.lower() == "dog":
        breed, breed_conf = predict_dog_breed(path)
    elif animal.lower() == "cat":
        breed, breed_conf = predict_cat_breed(path)

    color = extract_dominant_color(path)
    result = {
        "animal": animal,
        "breed": breed,
        "color": color,
        "confidence": round(float(conf) * 100.0, 2)
    }

    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute("""
        INSERT INTO records (filename, animal, breed, color, confidence, timestamp)
        VALUES (?, ?, ?, ?, ?, ?)
        """, (filename, animal, breed, color, float(result["confidence"]), datetime.now().isoformat()))
        conn.commit()

    return _json(200, result)

@app.get("/records")
@require_public_key
def records():
    out = []
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute("SELECT animal, breed, color, confidence FROM records ORDER BY id DESC")
        for animal, breed, color, conf_raw in c.fetchall():
            if isinstance(conf_raw, bytes):
                try: conf = struct.unpack('f', conf_raw)[0]
                except Exception: conf = 0.0
            else:
                conf = float(conf_raw)
            out.append({
                "animal": animal.decode() if isinstance(animal, bytes) else animal,
                "breed":  breed.decode()  if isinstance(breed,  bytes) else breed,
                "color":  color.decode()  if isinstance(color,  bytes) else color,
                "confidence": round(conf, 2)
            })
    return _json(200, out)

@app.post("/breed")
@require_public_key
@limiter.limit("10/second")
def breed_classification():
    global MODEL_LOADED
    code, msg = _file_guards(request.files)
    if code: return _bad(code, msg)

    f = request.files["image"]
    filename = datetime.now().strftime('%Y%m%d%H%M%S') + '_' + f.filename
    path = os.path.join(UPLOAD_FOLDER, filename)
    f.save(path)

    animal, _ = predict_single_image(path)
    if animal: MODEL_LOADED = True

    if animal and animal.lower() == "dog":
        breed, confidence = predict_dog_breed(path)
    elif animal and animal.lower() == "cat":
        breed, confidence = predict_cat_breed(path)
    else:
        breed, confidence = "Unknown", 0.0

    return _json(200, {
        "animal": animal,
        "breed": breed,
        "confidence": round(float(confidence) * 100.0, 2)
    })

# ====== Error handler ======
@app.errorhandler(Exception)
def handle_err(e):
    code = e.code if isinstance(e, HTTPException) else 500
    HTTP_ERR.labels(request.path, e.__class__.__name__).inc()
    # attach trace id to error logs as well
    span = trace.get_current_span()
    span_ctx = span.get_span_context() if span else None
    trace_id = f"{span_ctx.trace_id:032x}" if (span_ctx and span_ctx.trace_id) else None
    logging.getLogger("app").error(json.dumps({
        "ts": time.time(),
        "rid": getattr(request, "_rid", "-"),
        "trace_id": trace_id,
        "path": request.path,
        "error_type": e.__class__.__name__,
        "error": str(e)[:500]
    }))
    return _bad(code, str(e))

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
