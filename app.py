from flask import Flask, request, jsonify
import sqlite3
import os
from datetime import datetime
from dotenv import load_dotenv
from predict_image import predict_single_image
from PIL import Image
from predict_breed import predict_dog_breed
from predict_cat_breed import predict_cat_breed

app = Flask(__name__)
UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

DB_FILE = 'cat_dog.db'

load_dotenv()
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

def extract_dominant_color(img_path):
    img = Image.open(img_path).convert('RGB')
    colors = img.getcolors(img.size[0] * img.size[1])  
    dominant = max(colors, key=lambda tup: tup[0])    
    r, g, b = dominant[1]
    return rgb_to_color_name(r, g, b)

def rgb_to_color_name(r, g, b):
    if r > 200 and g > 200 and b > 200:
        return "White"
    elif r < 50 and g < 50 and b < 50:
        return "Black"
    elif r > g and r > b:
        return "Red-ish"
    elif g > r and g > b:
        return "Green-ish"
    elif b > r and b > g:
        return "Blue-ish"
    else:
        return f"RGB({r},{g},{b})"

def init_db():
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            CREATE TABLE IF NOT EXISTS records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                filename TEXT,
                animal TEXT,
                breed TEXT,
                color TEXT,
                confidence REAL,
                timestamp TEXT
            )
        ''')
        conn.commit()


init_db()

@app.route('/classify', methods=['POST'])
def classify():
    if 'image' not in request.files:
        return jsonify({'error': 'No file provided'}), 400

    file = request.files['image']
    filename = datetime.now().strftime('%Y%m%d%H%M%S') + '_' + file.filename
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)

    animal, confidence = predict_single_image(filepath)
    if animal is None:
        return jsonify({'error': 'Failed to analyze image'}), 500

    breed, breed_conf = ("Unknown", 0)
    if animal.lower() == "dog":
        breed, breed_conf = predict_dog_breed(filepath)
    elif animal.lower() == "cat":
        breed, breed_conf = predict_cat_breed(filepath)

    color = extract_dominant_color(filepath)

    result = {
        'animal': animal,
        'breed': breed,
        'color': color,
        'confidence': float(round(confidence * 100, 2))
    }

    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('''
            INSERT INTO records (filename, animal, breed, color, confidence, timestamp)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (filename, animal, breed, color, float(result['confidence']), datetime.now().isoformat()))
        conn.commit()

    return jsonify(result)




@app.route('/records', methods=['GET'])
def records():
    import struct  
    
    with sqlite3.connect(DB_FILE) as conn:
        c = conn.cursor()
        c.execute('SELECT animal, breed, color, confidence FROM records ORDER BY id DESC')
        rows = c.fetchall()
        result = []
        for r in rows:
            animal = r[0].decode() if isinstance(r[0], bytes) else r[0]
            breed = r[1].decode() if isinstance(r[1], bytes) else r[1]
            color = r[2].decode() if isinstance(r[2], bytes) else r[2]

            confidence_raw = r[3]
            if isinstance(confidence_raw, bytes):
                try:
                    confidence = struct.unpack('f', confidence_raw)[0]
                except Exception:
                    confidence = 0.0
            else:
                confidence = float(confidence_raw)

            result.append({
                'animal': animal,
                'breed': breed,
                'color': color,
                'confidence': round(confidence, 2)
            })


    return jsonify(result)

@app.route('/breed', methods=['POST'])
def breed_classification():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    file = request.files['image']
    filename = datetime.now().strftime('%Y%m%d%H%M%S') + '_' + file.filename
    filepath = os.path.join(UPLOAD_FOLDER, filename)
    file.save(filepath)

    animal, _ = predict_single_image(filepath)

    if animal.lower() == 'dog':
        breed, confidence = predict_dog_breed(filepath)
    elif animal.lower() == 'cat':
        breed, confidence = predict_cat_breed(filepath)
    else:
        breed, confidence = "Unknown", 0

    return jsonify({
        'animal': animal,
        'breed': breed,
        'confidence': round(confidence * 100, 2)
    })





if __name__ == '__main__':
    app.run(host="0.0.0.0", port=5000, debug=True)
