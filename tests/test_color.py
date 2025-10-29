from app import extract_dominant_color
from PIL import Image
import numpy as np, os

def _save(rgb, path="tests/data/tmp.jpg"):
    os.makedirs("tests/data", exist_ok=True)
    img = Image.new("RGB", (4,4), rgb)
    img.save(path)
    return path

def test_color_white():
    p = _save((255,255,255))
    assert extract_dominant_color(p) == "White"
