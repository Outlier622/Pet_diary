
import os, datetime, numpy as np, tensorflow as tf
from tensorflow import keras

ROOT_CANDIDATES = [
    "cat_dataset/gano_split",
    "cat_dataset",
]
def pick_dirs():
    for root in ROOT_CANDIDATES:
        t = os.path.join(root, "train")
        v = os.path.join(root, "val")
        if os.path.isdir(t) and os.path.isdir(v):
            return root, t, v
    raise FileNotFoundError(
        "did not find any directory containing train/val, please check：\n" +
        "\n".join(f"  - {os.path.join(c, 'train')} / {os.path.join(c, 'val')}" for c in ROOT_CANDIDATES)
    )

DATA_ROOT, TRAIN_DIR, VAL_DIR = pick_dirs()
print("[Using data root]", DATA_ROOT)
print("  train_dir:", TRAIN_DIR)
print("  val_dir  :", VAL_DIR)

# ---------------- Hyperparams ----------
IMG_SIZE   = (224, 224)
BATCH_SIZE = 32
SEED       = 1337
FREEZE_EPOCHS   = 30 
FINETUNE_EPOCHS = 5 
BASE_LR        = 3e-4
FINETUNE_LR    = 1e-5
UNFREEZE_LAYERS = 40 

MODEL_OUT  = "cat_breed_classifier_finetuned_6.keras"
BEST_CKPT  = "best_cat_breed.h5"
CLASS_NPY  = "cat_class_indices.npy"
TB_LOGDIR  = os.path.join("logs_cat", datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))

# ---------------- Datasets -------------
train_ds = keras.preprocessing.image_dataset_from_directory(
    TRAIN_DIR, image_size=IMG_SIZE, batch_size=BATCH_SIZE,
    label_mode="categorical", shuffle=True, seed=SEED)

val_ds = keras.preprocessing.image_dataset_from_directory(
    VAL_DIR, image_size=IMG_SIZE, batch_size=BATCH_SIZE,
    label_mode="categorical", shuffle=False)

num_classes = len(train_ds.class_names)
print("Classes:", train_ds.class_names)
class_to_index = {name: i for i, name in enumerate(train_ds.class_names)}
np.save(CLASS_NPY, class_to_index)
print(f"Saved class mapping -> {CLASS_NPY}")


def prep(x, y):
    x = tf.keras.applications.mobilenet_v2.preprocess_input(tf.cast(x, tf.float32))
    return x, y

augment = keras.Sequential([
    keras.layers.RandomFlip("horizontal"),
    keras.layers.RandomRotation(0.1),
    keras.layers.RandomZoom(0.1),
    keras.layers.RandomTranslation(0.1, 0.1),
], name="augment")

AUTOTUNE = tf.data.AUTOTUNE
train_ds = train_ds.map(prep).map(lambda x, y: (augment(x, training=True), y)).prefetch(AUTOTUNE)
val_ds   = val_ds.map(prep).prefetch(AUTOTUNE)

# ---------------- Model ----------------
base = tf.keras.applications.MobileNetV2(
    include_top=False, weights="imagenet", input_shape=(IMG_SIZE[0], IMG_SIZE[1], 3))
base.trainable = False 

inputs = keras.Input(shape=(IMG_SIZE[0], IMG_SIZE[1], 3))
x = base(inputs, training=False) 
x = keras.layers.GlobalAveragePooling2D()(x)
x = keras.layers.Dropout(0.2)(x)
outputs = keras.layers.Dense(num_classes, activation="softmax")(x)
model = keras.Model(inputs, outputs)

model.compile(
    optimizer=keras.optimizers.Adam(BASE_LR),
    loss="categorical_crossentropy",
    metrics=[
        "accuracy",
        keras.metrics.TopKCategoricalAccuracy(k=3, name="top3")
    ]
)

callbacks = [
    keras.callbacks.TensorBoard(TB_LOGDIR),
    keras.callbacks.ModelCheckpoint(BEST_CKPT, monitor="val_accuracy",
                                    save_best_only=True, mode="max", verbose=1),
    keras.callbacks.EarlyStopping(monitor="val_loss", patience=6,
                                  restore_best_weights=True, verbose=1),
    keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5,
                                      patience=3, min_lr=1e-6, verbose=1),
]

print("\n[Stage 1] Training head only...")
model.fit(train_ds, validation_data=val_ds, epochs=FREEZE_EPOCHS, callbacks=callbacks)

print("\n[Stage 2] Fine-tuning last layers...")
for layer in base.layers[-UNFREEZE_LAYERS:]:
    layer.trainable = True

model.compile(
    optimizer=keras.optimizers.Adam(FINETUNE_LR),
    loss="categorical_crossentropy",
    metrics=[
        "accuracy",
        keras.metrics.TopKCategoricalAccuracy(k=3, name="top3")
    ]
)

model.fit(train_ds, validation_data=val_ds, epochs=FINETUNE_EPOCHS, callbacks=callbacks)

# ---------------- Export ----------------
model.save(MODEL_OUT)
print(f"\nSaved model -> {MODEL_OUT}")
print(f"Best checkpoint -> {BEST_CKPT}")
