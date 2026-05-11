import RPi.GPIO as GPIO
import time
import logging

logger = logging.getLogger("ADAMS")

# =========================
# GPIO PINS
# =========================

BUZZER_PIN = 17
WHEEL_SENSOR_PIN = 27

# =========================
# GPIO SETUP
# =========================

GPIO.setwarnings(False)

GPIO.setmode(GPIO.BCM)

GPIO.setup(
    BUZZER_PIN,
    GPIO.OUT
)

GPIO.setup(
    WHEEL_SENSOR_PIN,
    GPIO.IN,
    pull_up_down=GPIO.PUD_DOWN
)

# =========================
# HARDWARE CONTROLLER
# =========================

class HardwareController:

    def __init__(self):

        self.last_buzz_time = 0

    # =========================
    # BUZZER ALERT
    # =========================

    def buzz_alert(self):

        current_time = time.time()

        # Prevent spam buzzing
        if current_time - self.last_buzz_time < 2:
            return

        logger.warning(
            "🚨 BUZZER ALERT ACTIVATED"
        )

        GPIO.output(
            BUZZER_PIN,
            GPIO.HIGH
        )

        time.sleep(0.5)

        GPIO.output(
            BUZZER_PIN,
            GPIO.LOW
        )

        self.last_buzz_time = current_time

    # =========================
    # WHEEL SENSOR
    # =========================

    def is_hands_on_wheel(self):

        return GPIO.input(
            WHEEL_SENSOR_PIN
        ) == GPIO.HIGH

    # =========================
    # CLEANUP
    # =========================

    def cleanup(self):

        GPIO.output(
            BUZZER_PIN,
            GPIO.LOW
        )

        GPIO.cleanup()

        logger.info(
            "GPIO cleanup complete"
        )