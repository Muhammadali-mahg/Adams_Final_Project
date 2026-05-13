import cv2
import time
import logging

from collections import deque

from hardware import HardwareController
from cloud_sync import CloudSync

# =========================
# LOGGING SETUP
# =========================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(
            "logs/adams.log"
        ),
        logging.StreamHandler()
    ]
)

logger = logging.getLogger("ADAMS")

# =========================
# MAIN SYSTEM
# =========================

class AdamsVisionSystem:

    def __init__(self):

        logger.info(
            "🚀 Starting ADAMS"
        )

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

        self.cap = cv2.VideoCapture(0)

        if not self.cap.isOpened():

            logger.error(
                "❌ Camera failed"
            )

            exit()

        # =========================
        # CASCADES
        # =========================

        self.face_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades +
            'haarcascade_frontalface_default.xml'
        )

        self.eye_cascade = cv2.CascadeClassifier(
            cv2.data.haarcascades +
            'haarcascade_eye.xml'
        )

        # =========================
        # STATES
        # =========================

        self.driver_state = "NORMAL"

        self.emotion = "FOCUSED"

        self.no_face_counter = 0

        self.eyes_closed_start = None

        self.last_face_pos = (0, 0)

        self.movement_history = deque(
            maxlen=20
        )

    # =========================
    # CHANGE STATE
    # =========================

    def set_state(self, new_state):

        if new_state != self.driver_state:

            logger.warning(
                f"STATE CHANGED: {self.driver_state} -> {new_state}"
            )

            self.driver_state = new_state

    # =========================
    # MAIN LOOP
    # =========================

    def run(self):

        while True:

            ret, frame = self.cap.read()

            if not ret:

                logger.error(
                    "❌ Failed to capture frame"
                )

                break

            gray = cv2.cvtColor(
                frame,
                cv2.COLOR_BGR2GRAY
            )

            faces = self.face_cascade.detectMultiScale(
                gray,
                scaleFactor=1.1,
                minNeighbors=5
            )

            # =========================
            # NO FACE
            # =========================

            if len(faces) == 0:

                self.no_face_counter += 1

                if self.no_face_counter > 30:

                    self.set_state(
                        "DISTRACTED"
                    )

            else:

                self.no_face_counter = 0

                (x, y, w, h) = faces[0]

                # =========================
                # HEAD MOVEMENT
                # =========================

                movement = abs(
                    x - self.last_face_pos[0]
                ) + abs(
                    y - self.last_face_pos[1]
                )

                self.last_face_pos = (
                    x,
                    y
                )

                self.movement_history.append(
                    movement
                )

                avg_movement = sum(
                    self.movement_history
                ) / len(
                    self.movement_history
                )

                # =========================
                # DIZZINESS
                # =========================

                if avg_movement > 40:

                    self.set_state(
                        "DIZZY"
                    )

                else:

                    self.set_state(
                        "NORMAL"
                    )

                # =========================
                # EYE DETECTION
                # =========================

                roi_gray = gray[
                    y:y+h,
                    x:x+w
                ]

                eyes = self.eye_cascade.detectMultiScale(
                    roi_gray,
                    scaleFactor=1.1,
                    minNeighbors=8
                )

                if len(eyes) == 0:

                    if self.eyes_closed_start is None:

                        self.eyes_closed_start = time.time()

                    closed_time = (
                        time.time() -
                        self.eyes_closed_start
                    )

                    if closed_time > 2:

                        self.set_state(
                            "DROWSY"
                        )

                else:

                    self.eyes_closed_start = None

            # =========================
            # WHEEL SENSOR
            # =========================

            hands_on_wheel = (
                self.hardware.is_hands_on_wheel()
            )

            # =========================
            # SMART ALERTS
            # =========================

            danger_states = [
                "DISTRACTED",
                "DIZZY",
                "DROWSY"
            ]

            if (
                self.driver_state in danger_states
                and not hands_on_wheel
            ):

                self.hardware.buzz_alert()

            # =========================
            # EMOTION SYSTEM
            # =========================

            if self.driver_state == "NORMAL":

                self.emotion = "RELAXED"

            elif self.driver_state == "DROWSY":

                self.emotion = "SLEEPY"

            elif self.driver_state == "DIZZY":

                self.emotion = "STRESSED"

            elif self.driver_state == "DISTRACTED":

                self.emotion = "UNFOCUSED"

            # =========================
            # FIREBASE DATA
            # =========================

            self.cloud.update_data({

                "driver_state":
                self.driver_state,

                "emotion":
                self.emotion,

                "hands_on_wheel":
                hands_on_wheel,

                "timestamp":
                time.time()

            })

            # =========================
            # DISPLAY UI
            # =========================

            cv2.putText(
                frame,
                f"STATE: {self.driver_state}",
                (20, 40),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (0, 255, 0),
                2
            )

            cv2.putText(
                frame,
                f"EMOTION: {self.emotion}",
                (20, 80),
                cv2.FONT_HERSHEY_SIMPLEX,
                1,
                (255, 255, 255),
                2
            )

            cv2.putText(
                frame,
                f"HANDS ON WHEEL: {hands_on_wheel}",
                (20, 120),
                cv2.FONT_HERSHEY_SIMPLEX,
                0.8,
                (255, 255, 0),
                2
            )

            cv2.imshow(
                "ADAMS SYSTEM",
                frame
            )

            # =========================
            # QUIT
            # =========================

            if cv2.waitKey(1) & 0xFF == ord('q'):

                break

        # =========================
        # CLEANUP
        # =========================

        logger.info(
            "🛑 Stopping ADAMS"
        )

        self.hardware.cleanup()

        self.cap.release()

        cv2.destroyAllWindows()

# =========================
# START SYSTEM
# =========================

if __name__ == "__main__":

    system = AdamsVisionSystem()

    system.run()