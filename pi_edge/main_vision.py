import cv2
import firebase_admin
from firebase_admin import credentials, db
import time
import threading
from deepface import DeepFace

# --- 1. CONNECT TO FIREBASE ---
cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred, {
    'databaseURL': 'https://adams-system-a1998-default-rtdb.asia-southeast1.firebasedatabase.app/' # <--- PASTE YOUR URL HERE
})
ref = db.reference('/driver_status')

class AdamsPi:
    def __init__(self):
        self.cap = cv2.VideoCapture(0)
        self.face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.py')
        self.status = {
            "emotion": "neutral",
            "distracted": False,
            "last_sync": 0
        }

    def run(self):
        print("🟢 Pi is watching... Check Firebase now!")
        distract_timer = 0
        
        while True:
            ret, frame = self.cap.read()
            if not ret: break

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            faces = self.face_cascade.detectMultiScale(gray, 1.1, 4)

            # --- DISTRACTION LOGIC ---
            if len(faces) == 0:
                distract_timer += 1
            else:
                distract_timer = 0
                self.status["distracted"] = False

            if distract_timer > 20: # Roughly 2 seconds
                self.status["distracted"] = True

            # --- EMOTION LOGIC (Every 3 seconds) ---
            if int(time.time()) % 3 == 0:
                try:
                    res = DeepFace.analyze(frame, actions=['emotion'], enforce_detection=False, silent=True)
                    self.status["emotion"] = res[0]['dominant_emotion']
                except:
                    pass

            # --- PUSH TO FIREBASE ---
            self.status["last_sync"] = time.time()
            ref.set(self.status)

            # Local Preview
            cv2.imshow("Pi Cam", frame)
            if cv2.waitKey(1) & 0xFF == ord('q'): break

if __name__ == "__main__":
    adams = AdamsPi()
    adams.run()