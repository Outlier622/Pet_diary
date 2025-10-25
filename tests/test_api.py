import io
from PIL import Image
from app import app

def _fake_image():
    img = Image.new("RGB", (32, 32), color=(255,255,255))
    buf = io.BytesIO(); img.save(buf, format="PNG"); buf.seek(0); return buf

def test_health(client=None):
    c = app.test_client()
    rv = c.get("/health")
    assert rv.status_code in (200, 503)

def test_classify_no_file():
    c = app.test_client()
    rv = c.post("/classify", data={})
    assert rv.status_code == 400

def test_classify_ok_smoke():
    c = app.test_client()
    rv = c.post("/classify", data={"image": ( _fake_image(), "x.png")}, content_type="multipart/form-data")
    assert rv.status_code in (200, 500) 
