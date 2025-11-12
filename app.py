import os, time, logging, sqlite3, struct, json, uuid
from datetime import datetime
from functools import wraps

from flask import Flask, request, jsonify, Response
from werkzeug.exceptions import HTTPException
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from dotenv import load_dotenv
from PIL import Image, UnidentifiedImageError  
from werkzeug.utils import secure_filename      
import psutil

try:
    import pillow_heif  
    pillow_heif.register_heif_opener()
except Exception:
    pass

# --- inference imports ---
from predict_image import predict_single_image
from predict_breed import predict_dog_breed
from predict_cat_breed import predict_cat_breed
# -------------------------

# --- OpenTelemetry (optional) ---
OTEL_ENABLED = True
try:
    from opentelemetry import trace as _otel_trace
    from opentelemetry.instrumentation.flask import FlaskInstrumentor
    try:
        from opentelemetry.instrumentation.requests import RequestsInstrumentor  
    except Exception:
        RequestsInstrumentor = None
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    try:
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter  
    except Exception:
        OTLPSpanExporter = None
    trace = _otel_trace
except Exception:
    OTEL_ENABLED = False
    class _NoTrace:
        def get_tracer(self, *a, **k): return None
        def get_current_span(self): return None
    class _NoInstr:
        def instrument_app(self, *a, **k): pass
        def instrument(self, *a, **k): pass
    trace = _NoTrace()
    FlaskInstrumentor = _NoInstr
    RequestsInstrumentor = None
    TracerProvider = object
    BatchSpanProcessor = object
    OTLPSpanExporter = None
# --------------------------------

load_dotenv()

# ====== Configs / Security ======
APP_VERSION    = os.getenv("APP_VERSION", "dev")
MODEL_REF      = os.getenv("MODEL_REF", "unknown")
APP_TOKEN      = os.getenv("APP_TOKEN", "dev-admin")
PUBLIC_API_KEY = os.getenv("PUBLIC_API_KEY", "dev-key")
API_KEY_REQUIRED = os.getenv("API_KEY_REQUIRED", "true").lower() == "true"

ALLOWED_TYPES = {
    "image/jpeg", "image/png", "image/webp", "image/heic", "image/heif",
    "application/octet-stream" 
}
ALLOWED_EXTS = {"jpg", "jpeg", "png", "webp", "heic", "heif"}
MAX_SIZE = 10 * 1024 * 1024  # 5MB

UPLOAD_FOLDER = os.getenv("UPLOAD_FOLDER", "uploads")
DB_FILE       = os.getenv("DB_FILE", "cat_dog.db")
WORKERS_URL   = os.getenv("WORKERS_URL")
OTLP_ENDPOINT = os.getenv("OTLP_ENDPOINT", "http://otel-collector:4318/v1/traces")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ====== App ======
app = Flask(__name__)
# [SEC] hard request cap at Flask layer (multipart overhead ≈ +1MB)
app.config["MAX_CONTENT_LENGTH"] = MAX_SIZE + 1024 * 1024

limiter = Limiter(get_remote_address, app=app, default_limits=["100/minute"])  # already present

# ====== OpenTelemetry (init AFTER app is created) ======
if OTEL_ENABLED:
    tp = TracerProvider()
    trace.set_tracer_provider(tp)
    if OTLPSpanExporter:
        tp.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=OTLP_ENDPOINT)))
    try:
        FlaskInstrumentor().instrument_app(app)
    except Exception:
        pass
    if RequestsInstrumentor is not None:
        try:
            RequestsInstrumentor().instrument()
        except Exception:
            pass
    tracer = trace.get_tracer(__name__)
else:
    tracer = None

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

def _extension_ok(filename: str) -> bool:
    # [SEC] allow only specific safe extensions
    if not filename:
        return False
    ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    return ext in ALLOWED_EXTS

def _verify_image_stream(file_storage) -> bool:
    """
    [SEC] Decode-check uploaded image stream to block disguised files.
    Do not trust mimetype alone.
    """
    pos = file_storage.stream.tell()
    try:
        img = Image.open(file_storage.stream)
        img.verify()  # validate structure
        file_storage.stream.seek(pos)  # reset for subsequent save
        return True
    except (UnidentifiedImageError, OSError):
        try:
            file_storage.stream.seek(pos)
        except Exception:
            pass
        return False

def _file_guards(fs):
    if "image" not in fs:
        return 400, "no file field 'image'"
    f = fs["image"]
    if not f or not getattr(f, "mimetype", None):
        return 400, "bad file"

    filename = (getattr(f, "filename", "") or "").strip()
    mimetype = (f.mimetype or "").lower()

    if not (mimetype.startswith("image/") or mimetype in ALLOWED_TYPES):
        return 400, "bad content-type"

    if "." in filename:
        ext = filename.rsplit(".", 1)[-1].lower()
        if ext not in ALLOWED_EXTS:
            return 400, "bad filename"

    try:
        f.seek(0, os.SEEK_END)
        sz = f.tell()
        f.seek(0)
    except Exception:
        return 400, "bad file stream"
    if sz > MAX_SIZE:
        return 400, "file too large"

    if not _verify_image_stream(f):
        return 400, "corrupt or invalid image"

    return 0, "ok"


def _secure_save_file(f):
    """[SEC] save to randomized, sanitized filename; no user-controlled path."""
    ext = f.filename.rsplit(".", 1)[-1].lower()
    safe_name = secure_filename(f"{uuid.uuid4().hex}.{ext}")
    path = os.path.join(UPLOAD_FOLDER, safe_name)
    f.stream.seek(0)
    f.save(path)
    return safe_name, path

def extract_dominant_color(img_path):
  
    
    import numpy as np, colorsys
    from PIL import Image

  
    TARGET_SIZE = 256
    GAUSS_SIGMA = 0.28     
    GREEN_SUPPRESS = 0.25   
    BLUE_SUPPRESS  = 0.35   
    BG_DOM_THRESH  = 0.50     
    SAT_MIN        = 0.12     
    VAL_BLACK_MAX  = 0.10     
    VAL_WHITE_MIN  = 0.97      
    H_BINS         = 36         
 

    def rgb_to_hsv01_arr(rgb):
        rgb = rgb.astype(np.float32) / 255.0
        r, g, b = rgb[:,0], rgb[:,1], rgb[:,2]
        mx, mn = np.maximum.reduce([r,g,b]), np.minimum.reduce([r,g,b])
        diff = mx - mn
        h = np.zeros_like(mx)
        mask = diff > 1e-6
        r_eq = (mx == r) & mask
        g_eq = (mx == g) & mask
        b_eq = (mx == b) & mask
        h[r_eq] = ((g[r_eq] - b[r_eq]) / diff[r_eq]) % 6.0
        h[g_eq] = ((b[g_eq] - r[g_eq]) / diff[g_eq]) + 2.0
        h[b_eq] = ((r[b_eq] - g[b_eq]) / diff[b_eq]) + 4.0
        h = (h / 6.0) % 1.0
        s = np.zeros_like(mx)
        s[mx > 1e-6] = diff[mx > 1e-6] / mx[mx > 1e-6]
        v = mx
        return h, s, v

    def name_color_from_hsv(h, s, v):
        h_deg = h * 360.0
        if v > VAL_WHITE_MIN and s < 0.08: return "White"
        if v < VAL_BLACK_MAX:              return "Black"
        if s < 0.12:
            return "Silver" if v >= 0.7 else "Gray"

        warm = 15 <= h_deg <= 65
        if warm:
            if s < 0.22 and v > 0.85:                     return "Cream"
            if s < 0.25 and 0.65 < v <= 0.85:             return "Beige"
            if 20 <= h_deg <= 45 and 0.20 <= s <= 0.55 and 0.55 <= v <= 0.85: return "Tan"
            if 38 <= h_deg <= 52 and s >= 0.40 and v >= 0.50:                 return "Gold"
            if 15 <= h_deg <= 45 and s >= 0.35 and v < 0.55:                   return "Brown"
            if 52 <  h_deg <= 65 and s >= 0.40 and v >= 0.60:                  return "Yellow"
            if 20 <= h_deg <  38 and s >= 0.50 and v >= 0.50:                  return "Orange"

        if (h_deg >= 345 or h_deg < 15):  return "Red"
        if 160 <= h_deg < 200:            return "Teal" if (v < 0.6 and s >= 0.3) else "Cyan"
        if 80  <= h_deg < 160:            return "Green"
        if 200 <= h_deg < 260:            return "Blue"
        if 260 <= h_deg < 290:            return "Purple"
        if 290 <= h_deg < 330:            return "Magenta"
        if 330 <= h_deg < 345:            return "Pink"
        return "Gold" if (35 <= h_deg <= 55) else ("Green" if 90 <= h_deg <= 150 else "Red")

    img = Image.open(img_path).convert("RGB")
    img.thumbnail((TARGET_SIZE, TARGET_SIZE))
    w, h = img.size
    arr = np.asarray(img) 
    flat = arr.reshape(-1, 3)

    yy, xx = np.mgrid[0:h, 0:w]
    cy, cx = (h-1)/2.0, (w-1)/2.0
    dy, dx = (yy - cy) / h, (xx - cx) / w
    dist2 = dx*dx + dy*dy
    gauss = np.exp(-dist2 / (2 * (GAUSS_SIGMA**2)))
    weights = gauss.reshape(-1)

    H, S, V = rgb_to_hsv01_arr(flat)
    keep = (S >= SAT_MIN) & (V >= VAL_BLACK_MAX) & (V <= 0.995)
    if keep.sum() < 50:
        keep = np.ones_like(weights, dtype=bool)

    Hk, Sk, Vk = H[keep], S[keep], V[keep]
    wk = weights[keep]

    is_green = (Hk >= 80/360) & (Hk <= 160/360)
    is_blue  = (Hk >= 200/360) & (Hk <= 250/360)

    green_ratio = (wk[is_green].sum() / wk.sum()) if wk.sum() > 0 else 0.0
    blue_ratio  = (wk[is_blue].sum()  / wk.sum()) if wk.sum() > 0 else 0.0

    wk2 = wk.copy()
    if green_ratio >= BG_DOM_THRESH:
        wk2[is_green] *= GREEN_SUPPRESS
    if blue_ratio  >= BG_DOM_THRESH:
        wk2[is_blue]  *= BLUE_SUPPRESS

    bins = np.linspace(0.0, 1.0, H_BINS+1)
    hist, _ = np.histogram(Hk, bins=bins, weights=wk2)
    top_bin = np.argmax(hist)
    if hist[top_bin] <= 1e-9:
        idx = np.argmax(wk2)
        h_star, s_star, v_star = float(Hk[idx]), float(Sk[idx]), float(Vk[idx])
    else:
        b_lo, b_hi = bins[top_bin], bins[top_bin+1]
        in_bin = (Hk >= b_lo) & (Hk < b_hi)
        wbin = wk2[in_bin]
        if wbin.sum() < 1e-9:
            idx = np.argmax(wk2)
            h_star, s_star, v_star = float(Hk[idx]), float(Sk[idx]), float(Vk[idx])
        else:
            h_star = float(np.average(Hk[in_bin], weights=wbin))
            s_star = float(np.average(Sk[in_bin], weights=wbin))
            v_star = float(np.average(Vk[in_bin], weights=wbin))

    
    return name_color_from_hsv(h_star, s_star, v_star)



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

        # [SEC] add basic security headers for API responses
        resp.headers.setdefault("X-Content-Type-Options", "nosniff")
        resp.headers.setdefault("X-Frame-Options", "DENY")
        resp.headers.setdefault("Cache-Control", "no-store")

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
@app.get("/upload")
def upload_form():
    return """
    <!doctype html>
    <html>
    <head><meta charset="utf-8"><title>Upload test</title></head>
    <body style="font-family:sans-serif;padding:20px">
      <h3>Upload an image to /classify</h3>
      <form action="/classify" method="post" enctype="multipart/form-data">
        <input type="file" name="image" accept="image/*" required />
        <button type="submit">Upload</button>
      </form>
      
    </body>
    </html>
    """

@app.post("/classify")
@require_public_key
@limiter.limit("10/second")
def classify():
    global MODEL_LOADED
    code, msg = _file_guards(request.files)
    if code: return _bad(code, msg)

    f = request.files["image"]
    # [SEC] secure randomized filename, no user-controlled paths
    filename, path = _secure_save_file(f)

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
    filename, path = _secure_save_file(f)  # [SEC] same as /classify

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
    # [SEC] do not leak internal error details to clients
    public_msg = "internal error" if code == 500 else "request error"
    return _bad(code, public_msg)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "5000")))
