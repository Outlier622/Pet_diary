import os
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras.preprocessing import image


CANDIDATES = ["cat_dog_classifier.h5", "cat_dog_classifier.keras"]
model_path = None
for p in CANDIDATES:
    if os.path.exists(p):
        model_path = p
        break

if model_path is None:
    raise FileNotFoundError(
        "Error: did not find model file 'cat_dog_classifier.h5' or 'cat_dog_classifier.keras'."
    )

image_size = (224, 224)

print(f"Loading model: {model_path} ...")

loaded_model = keras.models.load_model(model_path, compile=False)
print("Model loaded successfully.")

def predict_single_image(img_path):
    """return (class_label, confidence)；fail return (None, None)"""
    if not os.path.exists(img_path):
        print(f"Error: can't find image file '{img_path}'. Please check path.")
        return None, None

    try:
        img = image.load_img(img_path, target_size=image_size)
        img_array = image.img_to_array(img)
        img_array = img_array / 255.0
        img_array = np.expand_dims(img_array, axis=0)

        prob = float(loaded_model.predict(img_array, verbose=0)[0][0])
        if prob >= 0.5:
            class_label = "Dog"
            confidence = prob
        else:
            class_label = "Cat"
            confidence = 1.0 - prob

        print(f"Predict result: {class_label} (Confidence: {confidence:.4f})")
        return class_label, confidence

    except Exception as e:
        print(f"Error happens when handling images: {e}")
        return None, None

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        predict_single_image(sys.argv[1])
