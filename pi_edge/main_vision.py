import logging
import time
from collections import deque
from pathlib import Path

import cv2

from cloud_sync import CloudSync
from hardware import HardwareController

# =========================
# SETTINGS
# =========================

BASE_DIR = Path(__file__).resolve().parent
LOG_DIR = BASE_DIR / "logs"
LOG_DIR.mkdir(exist_ok=True)

CAMERA_INDEX = 0
NO_FACE_FRAME_LIMIT = 30
DROWSY_SECONDS = 2
DIZZY_MOVEMENT_THRESHOLD = 40
MOVEMENT_HISTORY_SIZE = 20

DANGER_STATES = [
    "DISTRACTED",
    "DIZZY",
    "DROWSY",
]

EMOTIONS_BY_STATE = {
    "NORMAL": "RELAXED",
    "DROWSY": "SLEEPY",
    "DIZZY": "STRESSED",
    "DISTRACTED": "UNFOCUSED",
}

# =========================
# LOGGING SETUP
# =========================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_DIR / "adams.log"),
        logging.StreamHandler(),
    ],
)

logger = logging.getLogger("ADAMS")

# =========================
# MAIN SYSTEM
# =========================


class AdamsVisionSystem:

    def __init__(self):
        logger.info("Starting ADAMS")

        # =========================
        # HARDWARE
        # =========================

        self.hardware = HardwareController()

        # =========================
        # CLOUD
        # =========================

        self.cloud = CloudSync()
        self.cloud.start()

        # =========================
        # CAMERA
        # =========================

        self.cap = cv2.VideoCapture(CAMERA_INDEX)

        if not self.cap.isOpened():
            raise RuntimeError("Camera failed")

        # =========================
        # CASCADES
        # =========================

        self.face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )

        self.eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_eye.xml"
        )

        # =========================
        # STATES
        # =========================

        self.driver_state = "NORMAL"
        self.emotion = "FOCUSED"
        self.no_face_counter = 0
        self.eyes_closed_start = None
        self.last_face_pos = None
        self.movement_history = deque(maxlen=MOVEMENT_HISTORY_SIZE)
        self.closed_eye_seconds = 0
        self.avg_movement = 0
        self.eye_count = 0
        self.face_detected = False

    # =========================
    # CHANGE STATE
    # =========================

    def set_state(self, new_state):
        if new_state != self.driver_state:
            logger.warning(f"STATE CHANGED: {self.driver_state} -> {new_state}")
            self.driver_state = new_state

    # =========================
    # HELPERS
    # =========================

    def get_largest_face(self, faces):
        return max(faces, key=lambda face: face[2] * face[3])

    def update_emotion(self):
        self.emotion = EMOTIONS_BY_STATE.get(self.driver_state, "FOCUSED")

    def draw_status(self, frame, hands_on_wheel):
        cv2.putText(
            frame,
            f"STATE: {self.driver_state}",
            (20, 40),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (0, 255, 0),
            2,
        )

        cv2.putText(
            frame,
            f"EMOTION: {self.emotion}",
            (20, 80),
            cv2.FONT_HERSHEY_SIMPLEX,
            1,
            (255, 255, 255),
            2,
        )

        cv2.putText(
            frame,
            f"HANDS ON WHEEL: {hands_on_wheel}",
            (20, 120),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 0),
            2,
        )

    def sync_status(self, hands_on_wheel):
        self.cloud.update_data({
            "driver_state": self.driver_state,
            "emotion": self.emotion,
            "hands_on_wheel": hands_on_wheel,
            "face_detected": self.face_detected,
            "eye_count": self.eye_count,
            "avg_movement": round(self.avg_movement, 2),
            "closed_eye_seconds": round(self.closed_eye_seconds, 2),
            "timestamp": time.time(),
        })

    def cleanup(self):
        logger.info("Stopping ADAMS")
        self.cloud.stop()
        self.hardware.cleanup()
        self.cap.release()
        cv2.destroyAllWindows()

    # =========================
    # MAIN LOOP
    # =========================

    def run(self):
        try:
            while True:
                ret, frame = self.cap.read()

                if not ret:
                    logger.error("Failed to capture frame")
                    break

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)

                faces = self.face_cascade.detectMultiScale(
                    gray,
                    scaleFactor=1.1,
                    minNeighbors=5,
                )

                self.face_detected = len(faces) > 0
                self.eye_count = 0
                self.closed_eye_seconds = 0

                # =========================
                # NO FACE
                # =========================

                if not self.face_detected:
                    self.no_face_counter += 1
                    self.last_face_pos = None
                    self.movement_history.clear()
                    self.avg_movement = 0

                    if self.no_face_counter > NO_FACE_FRAME_LIMIT:
                        self.set_state("DISTRACTED")

                else:
                    self.no_face_counter = 0

                    x, y, w, h = self.get_largest_face(faces)

                    cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)

                    # =========================
                    # HEAD MOVEMENT
                    # =========================

                    if self.last_face_pos is None:
                        movement = 0
                    else:
                        movement = abs(x - self.last_face_pos[0]) + abs(
                            y - self.last_face_pos[1]
                        )

                    self.last_face_pos = (x, y)
                    self.movement_history.append(movement)
                    self.avg_movement = sum(self.movement_history) / len(
                        self.movement_history
                    )

                    # =========================
                    # DIZZINESS
                    # =========================

                    if self.avg_movement > DIZZY_MOVEMENT_THRESHOLD:
                        self.set_state("DIZZY")
                    else:
                        self.set_state("NORMAL")

                    # =========================
                    # EYE DETECTION
                    # =========================

                    roi_gray = gray[y:y + h, x:x + w]

                    eyes = self.eye_cascade.detectMultiScale(
                        roi_gray,
                        scaleFactor=1.1,
                        minNeighbors=8,
                    )

                    self.eye_count = len(eyes)

                    for ex, ey, ew, eh in eyes:
                        cv2.rectangle(
                            frame,
                            (x + ex, y + ey),
                            (x + ex + ew, y + ey + eh),
                            (255, 255, 0),
                            2,
                        )

                    if self.eye_count == 0:
                        if self.eyes_closed_start is None:
                            self.eyes_closed_start = time.time()

                        self.closed_eye_seconds = (
                            time.time() - self.eyes_closed_start
                        )

                        if self.closed_eye_seconds > DROWSY_SECONDS:
                            self.set_state("DROWSY")

                    else:
                        self.eyes_closed_start = None

                # =========================
                # WHEEL SENSOR
                # =========================

                hands_on_wheel = self.hardware.is_hands_on_wheel()

                # =========================
                # SMART ALERTS
                # =========================

                if (
                    self.driver_state in DANGER_STATES
                    and not hands_on_wheel
                ):
                    self.hardware.buzz_alert()

                # =========================
                # EMOTION + FIREBASE
                # =========================

                self.update_emotion()
                self.sync_status(hands_on_wheel)

                # =========================
                # DISPLAY UI
                # =========================

                self.draw_status(frame, hands_on_wheel)
                cv2.imshow("ADAMS SYSTEM", frame)

                # =========================
                # QUIT
                # =========================

                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

        finally:
            self.cleanup()


# =========================
# START SYSTEM
# =========================

if __name__ == "__main__":
    system = AdamsVisionSystem()
    system.run()
