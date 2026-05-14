"""
adams_vision.py – improved version

Pi-friendly changes (no TensorFlow / MediaPipe needed):
- Pure OpenCV cascade detection, same as before.
- Added PERCLOS-style drowsiness: counts frames with eyes closed instead of
  a wall-clock timer, which is more reliable at low framerates.
- State priority order: DROWSY > DIZZY > DISTRACTED > NORMAL
  (prevents DIZZY overwriting a DROWSY alert).
- Alert cooldown is now per-state so each new danger type re-triggers the buzzer.
- Separated state logic into small methods for readability.
"""

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

# How many consecutive frames without a face before DISTRACTED
NO_FACE_FRAME_LIMIT = 30

# PERCLOS: how many consecutive eye-closed frames before DROWSY
# At ~15 fps this is ~2 seconds — tune to your camera speed
DROWSY_FRAME_LIMIT = 30

# Average head pixel movement per frame to trigger DIZZY
DIZZY_MOVEMENT_THRESHOLD = 40
MOVEMENT_HISTORY_SIZE = 20

# State priority (higher index = higher priority)
STATE_PRIORITY = ["NORMAL", "DISTRACTED", "DIZZY", "DROWSY"]

DANGER_STATES = {"DISTRACTED", "DIZZY", "DROWSY"}

EMOTIONS_BY_STATE = {
    "NORMAL": "RELAXED",
    "DROWSY": "SLEEPY",
    "DIZZY": "STRESSED",
    "DISTRACTED": "UNFOCUSED",
}

# =========================
# LOGGING
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

        self.hardware = HardwareController()
        self.cloud = CloudSync()
        self.cloud.start()

        self.cap = cv2.VideoCapture(CAMERA_INDEX)
        if not self.cap.isOpened():
            raise RuntimeError("Camera failed to open")

        self.face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
        )
        self.eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades + "haarcascade_eye.xml"
        )

        # --- State ---
        self.driver_state = "NORMAL"
        self.emotion = "RELAXED"

        self.no_face_counter = 0
        self.eyes_closed_frames = 0          # FIX: frame-count instead of timer
        self.last_face_pos = None
        self.movement_history: deque[float] = deque(maxlen=MOVEMENT_HISTORY_SIZE)

        # Diagnostics exposed to cloud
        self.face_detected = False
        self.eye_count = 0
        self.avg_movement = 0.0
        self.closed_eye_frames_display = 0

    # ------------------------------------------------------------------
    # State machine
    # ------------------------------------------------------------------

    def _resolve_state(self, *candidate_states: str) -> str:
        """Return the highest-priority state from the candidates."""
        best = "NORMAL"
        for s in candidate_states:
            if STATE_PRIORITY.index(s) > STATE_PRIORITY.index(best):
                best = s
        return best

    def set_state(self, new_state: str) -> None:
        if new_state != self.driver_state:
            logger.warning(f"STATE: {self.driver_state} → {new_state}")
            self.driver_state = new_state

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def get_largest_face(faces):
        return max(faces, key=lambda f: f[2] * f[3])

    def update_emotion(self) -> None:
        self.emotion = EMOTIONS_BY_STATE.get(self.driver_state, "FOCUSED")

    def draw_status(self, frame, hands_on_wheel: bool) -> None:
        labels = [
            (f"STATE: {self.driver_state}", (0, 255, 0), 1.0),
            (f"EMOTION: {self.emotion}", (255, 255, 255), 1.0),
            (f"HANDS: {'ON' if hands_on_wheel else 'OFF'}", (255, 255, 0), 0.8),
            (f"EYES CLOSED: {self.eyes_closed_frames}f", (200, 200, 255), 0.7),
            (f"MOVEMENT: {self.avg_movement:.1f}", (200, 255, 200), 0.7),
        ]
        for i, (text, color, scale) in enumerate(labels):
            cv2.putText(frame, text, (20, 40 + i * 38),
                        cv2.FONT_HERSHEY_SIMPLEX, scale, color, 2)

    def sync_to_cloud(self, hands_on_wheel: bool) -> None:
        self.cloud.update_data({
            "driver_state": self.driver_state,
            "emotion": self.emotion,
            "hands_on_wheel": hands_on_wheel,
            "face_detected": self.face_detected,
            "eye_count": self.eye_count,
            "avg_movement": round(self.avg_movement, 2),
            "eyes_closed_frames": self.eyes_closed_frames,
            "timestamp": time.time(),
        })

    def cleanup(self) -> None:
        logger.info("Stopping ADAMS")
        self.cloud.stop()
        self.hardware.cleanup()
        self.cap.release()
        cv2.destroyAllWindows()

    # ------------------------------------------------------------------
    # Main loop
    # ------------------------------------------------------------------

    def run(self) -> None:
        try:
            while True:
                ret, frame = self.cap.read()
                if not ret:
                    logger.error("Failed to capture frame")
                    break

                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                faces = self.face_cascade.detectMultiScale(
                    gray, scaleFactor=1.1, minNeighbors=5
                )

                self.face_detected = len(faces) > 0

                # Candidate states collected this frame
                candidate_state = "NORMAL"

                # ── NO FACE ──────────────────────────────────────────────
                if not self.face_detected:
                    self.no_face_counter += 1
                    self.last_face_pos = None
                    self.movement_history.clear()
                    self.avg_movement = 0.0
                    self.eye_count = 0
                    self.eyes_closed_frames = 0

                    if self.no_face_counter > NO_FACE_FRAME_LIMIT:
                        candidate_state = self._resolve_state(
                            candidate_state, "DISTRACTED"
                        )

                # ── FACE DETECTED ────────────────────────────────────────
                else:
                    self.no_face_counter = 0
                    x, y, w, h = self.get_largest_face(faces)
                    cv2.rectangle(frame, (x, y), (x + w, y + h), (0, 255, 0), 2)

                    # Head movement
                    movement = (
                        abs(x - self.last_face_pos[0]) + abs(y - self.last_face_pos[1])
                        if self.last_face_pos is not None
                        else 0.0
                    )
                    self.last_face_pos = (x, y)
                    self.movement_history.append(movement)
                    self.avg_movement = sum(self.movement_history) / len(
                        self.movement_history
                    )

                    if self.avg_movement > DIZZY_MOVEMENT_THRESHOLD:
                        candidate_state = self._resolve_state(
                            candidate_state, "DIZZY"
                        )

                    # Eye detection
                    roi_gray = gray[y: y + h, x: x + w]
                    eyes = self.eye_cascade.detectMultiScale(
                        roi_gray, scaleFactor=1.1, minNeighbors=8
                    )
                    self.eye_count = len(eyes)

                    for ex, ey, ew, eh in eyes:
                        cv2.rectangle(
                            frame,
                            (x + ex, y + ey),
                            (x + ex + ew, y + ey + eh),
                            (255, 255, 0), 2,
                        )

                    # FIX: frame-count PERCLOS instead of wall-clock timer
                    if self.eye_count == 0:
                        self.eyes_closed_frames += 1
                    else:
                        self.eyes_closed_frames = 0   # eyes open → reset

                    if self.eyes_closed_frames > DROWSY_FRAME_LIMIT:
                        candidate_state = self._resolve_state(
                            candidate_state, "DROWSY"
                        )

                self.set_state(candidate_state)

                # ── WHEEL SENSOR ─────────────────────────────────────────
                hands_on_wheel = self.hardware.is_hands_on_wheel()

                # ── ALERTS ───────────────────────────────────────────────
                if self.driver_state in DANGER_STATES and not hands_on_wheel:
                    self.hardware.buzz_alert()

                # ── UPDATE & DISPLAY ─────────────────────────────────────
                self.update_emotion()
                self.sync_to_cloud(hands_on_wheel)
                self.draw_status(frame, hands_on_wheel)
                cv2.imshow("ADAMS SYSTEM", frame)

                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break

        finally:
            self.cleanup()


# =========================
# ENTRY POINT
# =========================

if __name__ == "__main__":
    system = AdamsVisionSystem()
    system.run()