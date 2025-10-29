from app.preprocess import normalize_image
import numpy as np

def test_normalize_range():
    arr = (np.ones((10,10,3))*255).astype("uint8")
    x = normalize_image(arr)
    assert x.min() >= 0 and x.max() <= 1
