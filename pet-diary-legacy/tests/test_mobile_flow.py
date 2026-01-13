import requests, uuid, os
BASE = os.getenv("BASE_URL","http://localhost:8000")
def test_mobile_flow_happy_path():
    img = "tests/data/sample.jpg"
    if not os.path.exists(img): return
    r = requests.post(f"{BASE}/predict",
        headers={"X-API-Key":"dev-key","Idempotency-Key":str(uuid.uuid4())},
        files={"file": ("sample.jpg", open(img,"rb"), "image/jpeg")})
    assert r.ok
