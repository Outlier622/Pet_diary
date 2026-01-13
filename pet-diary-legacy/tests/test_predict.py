import os, requests

BASE = os.getenv("BASE_URL", "http://localhost:8000")

def test_health_and_predict():
    assert requests.get(f"{BASE}/readyz").status_code in (200,503)
    img_path = "tests/data/sample.jpg" 
    if not os.path.exists(img_path): return
    r = requests.post(f"{BASE}/predict",
                      headers={"X-API-Key":"dev-key","Idempotency-Key":"it-1"},
                      files={"file": ("sample.jpg", open(img_path,"rb"), "image/jpeg")})
    assert r.status_code == 200
    body = r.json()
    assert "top1" in body and "score" in body
