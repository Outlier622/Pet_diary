import os
import io
import pytest
from PIL import Image
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_healthz(client):
    rv = client.get("/healthz")
    assert rv.status_code == 200
    data = rv.get_json()
    assert data["status"] == "ok"


def test_infer_endpoint(client):
    test_img = Image.new("RGB", (64, 64), color=(255, 255, 255))
    buf = io.BytesIO()
    test_img.save(buf, format="JPEG")
    buf.seek(0)

    rv = client.post("/classify", content_type="multipart/form-data", data={"file": (buf, "test.jpg")})

    assert rv.status_code in (200, 400)