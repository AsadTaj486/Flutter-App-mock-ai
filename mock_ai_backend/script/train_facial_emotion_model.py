# import os
# import numpy as np
# from keras.models import Sequential
# from keras.layers import Conv2D, MaxPooling2D, Dropout, Flatten, Dense, BatchNormalization
# from keras.preprocessing.image import ImageDataGenerator
# from keras.optimizers import Adam

# # Parameters
# img_size = 48
# batch_size = 64
# num_classes = 7
# epochs = 50
# emotion_classes = ['Angry', 'Disgust', 'Fear', 'Happy', 'Sad', 'Surprise', 'Neutral']

# # Paths
# base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'data', 'facial_emotion'))
# train_dir = os.path.join(base_dir, 'train')
# val_dir = os.path.join(base_dir, 'test')

# # Ensure class subfolders exist
# for base in [train_dir, val_dir]:
#     for emotion in emotion_classes:
#         path = os.path.join(base, emotion)
#         os.makedirs(path, exist_ok=True)

# print(f"\n✅ Using training directory: {train_dir}")
# print(f"✅ Using validation directory: {val_dir}\n")

# # Image augmentation
# train_datagen = ImageDataGenerator(
#     rescale=1./255,
#     rotation_range=40,
#     zoom_range=0.3,
#     width_shift_range=0.2,
#     height_shift_range=0.2,
#     shear_range=0.2,
#     horizontal_flip=True,
#     fill_mode='nearest'
# )

# val_datagen = ImageDataGenerator(rescale=1./255)

# # Data generators
# train_generator = train_datagen.flow_from_directory(
#     train_dir,
#     target_size=(img_size, img_size),
#     batch_size=batch_size,
#     color_mode='grayscale',
#     class_mode='categorical'
# )

# val_generator = val_datagen.flow_from_directory(
#     val_dir,
#     target_size=(img_size, img_size),
#     batch_size=batch_size,
#     color_mode='grayscale',
#     class_mode='categorical'
# )

# # ✅ CNN Model with BatchNormalization + Dropout
# model = Sequential([
#     Conv2D(64, (3, 3), activation='relu', input_shape=(img_size, img_size, 1)),
#     BatchNormalization(),
#     MaxPooling2D(2, 2),
#     Dropout(0.25),

#     Conv2D(128, (3, 3), activation='relu'),
#     BatchNormalization(),
#     MaxPooling2D(2, 2),
#     Dropout(0.25),

#     Conv2D(256, (3, 3), activation='relu'),
#     BatchNormalization(),
#     MaxPooling2D(2, 2),
#     Dropout(0.25),

#     Flatten(),
#     Dense(256, activation='relu'),
#     Dropout(0.5),
#     Dense(num_classes, activation='softmax')
# ])

# # Compile
# model.compile(
#     optimizer=Adam(learning_rate=0.0001),
#     loss='categorical_crossentropy',
#     metrics=['accuracy']
# )

# # 🏋️ Train
# model.fit(train_generator, epochs=epochs, validation_data=val_generator)

# # Paths to model
# model_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'models'))
# os.makedirs(model_dir, exist_ok=True)
# model_path = os.path.join(model_dir, 'facial_emotion_model.h5')

# # 🧹 Delete old model before saving new one
# if os.path.exists(model_path):
#     os.remove(model_path)
#     print("🧹 Old model deleted.")

# # 💾 Save model
# model.save(model_path)
# print(f"\n✅ Improved model saved at: {model_path}")
