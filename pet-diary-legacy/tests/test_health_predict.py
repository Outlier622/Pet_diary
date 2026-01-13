import os, requests, uuid, time

BASE = os.getenv("BASE_URL", "http://localhost:5000")

def test_ready_and_predict_smoke():
    requests.get(f"{BASE}/livez")
    r = requests.get(f"{BASE}/readyz")
    assert r.status_code in (200,503)

    img = "tests/data/tmp.jpg"
    if not os.path.exists(img):
        import PIL.Image as I; I.new("RGB",(4,4),(200,0,0)).save(img)

    r = requests.post(f"{BASE}/classify",
        headers={"X-API-Key":"dev-key", "Idempotency-Key":str(uuid.uuid4())},
        files={"image": ("tmp.jpg", open(img,"rb"), "image/jpeg")})
    assert r.status_code in (200,500) 
