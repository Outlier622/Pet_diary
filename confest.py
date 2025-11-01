import os, tempfile, shutil, uuid
import pytest

@pytest.fixture(autouse=True)
def _fixed_seed(monkeypatch):
    import numpy as np, random
    np.random.seed(42); random.seed(42)

@pytest.fixture(scope="session")
def test_images(tmp_path_factory):
    from PIL import Image
    d = tmp_path_factory.mktemp("imgs")
    for name, color in [("sample-dog.jpg",(200,0,0)),("sample-cat.jpg",(0,0,200))]:
        p = d / name
        Image.new("RGB",(32,32),color).save(p)
    return d

@pytest.fixture
def app_env(tmp_path, monkeypatch):
    monkeypatch.setenv("UPLOAD_FOLDER", str(tmp_path/"uploads"))
    monkeypatch.setenv("DB_FILE", str(tmp_path/"test.db"))
    monkeypatch.setenv("PUBLIC_API_KEY", "dev-key")
    monkeypatch.setenv("APP_TOKEN", "dev-admin")
    os.makedirs(tmp_path/"uploads", exist_ok=True)

@pytest.fixture
def client(app_env):
    from app import app
    app.config.update(TESTING=True)
    return app.test_client()

@pytest.fixture
def mock_predict(monkeypatch):
    monkeypatch.setenv("API_KEY_REQUIRED", "false")
    import app
    monkeypatch.setattr(app, "predict_single_image", lambda p: ("dog", 0.91))
    monkeypatch.setattr(app, "predict_dog_breed",  lambda p: ("beagle", 0.88))
    monkeypatch.setattr(app, "predict_cat_breed",   lambda p: ("siamese", 0.77))
