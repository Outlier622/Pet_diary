import numpy as np
from tensorflow.keras.preprocessing import image
from tensorflow.keras.models import load_model
import os


MODEL_PATH = 'cat_breed_classifier_finetuned_6.keras'
CLASS_INDEX_PATH = 'cat_class_indices.npy' 


print("Loading cat model：", MODEL_PATH)
model = load_model(MODEL_PATH)


if not os.path.exists(CLASS_INDEX_PATH):
    raise FileNotFoundError(f"Did not find file：{CLASS_INDEX_PATH}")
class_indices = np.load(CLASS_INDEX_PATH, allow_pickle=True).item()
index_to_class = {v: k for k, v in class_indices.items()}


def predict_cat_breed(img_path):
    img = image.load_img(img_path, target_size=(224, 224))
    img_array = image.img_to_array(img) / 255.0
    img_array = np.expand_dims(img_array, axis=0)

    prediction = model.predict(img_array)[0]
    top_index = np.argmax(prediction)
    breed_name = index_to_class[top_index]
    confidence = prediction[top_index]

    return breed_name, float(confidence)
