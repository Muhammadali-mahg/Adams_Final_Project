import logging
import time

try:
    import RPi.GPIO as GPIO
except (ImportError, RuntimeError):
    GPIO = None

logger = logging.getLogger("ADAMS")

# =============================
# Pins
# =============================
BUZZER_PIN = 17
WHEEL_SENSOR_PINS = [5, 27]

# =============================
# Config
# =============================
BUZZ_COOLDOWN_SECONDS = 2

WHEEL_DEBOUNCE_READS = 3
WHEEL_DEBOUNCE_DELAY = 0.01

BUZZ_PATTERNS = {
    "DISTRACTED": [(0.15, 0.10), (0.15, 0.10)],
    "DIZZY": [(0.25, 0.10), (0.25, 0.10), (0.25, 0.10)],
    "DROWSY": [(0.60, 0.10), (0.60, 0.00)],
    "DEFAULT": [(0.30, 0.00)],
}


class HardwareController:

    def __init__(self):
        self.last_buzz_time = 0.0
        self.gpio_enabled = GPIO is not None

        if not self.gpio_enabled:
            logger.warning("GPIO unavailable – simulation mode")
            return

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BCM)

        # -------------------------
        # OUTPUT
        # -------------------------
        GPIO.setup(BUZZER_PIN, GPIO.OUT)

        # -------------------------
        # INPUT (wheel sensors)
        # -------------------------
        for pin in WHEEL_SENSOR_PINS:
            GPIO.setup(pin, GPIO.IN, pull_up_down=GPIO.PUD_UP)

        GPIO.output(BUZZER_PIN, GPIO.LOW)
        logger.info("GPIO initialized")

    # =============================
    # BUZZER
    # =============================
    def buzz_alert(self, state: str = "DEFAULT") -> None:

        if not self.gpio_enabled:
            return

        now = time.time()
        if now - self.last_buzz_time < BUZZ_COOLDOWN_SECONDS:
            return

        self.last_buzz_time = now

        pattern = BUZZ_PATTERNS.get(state, BUZZ_PATTERNS["DEFAULT"])

        try:
            for on_t, off_t in pattern:
                GPIO.output(BUZZER_PIN, GPIO.HIGH)
                time.sleep(on_t)
                GPIO.output(BUZZER_PIN, GPIO.LOW)
                time.sleep(off_t)

        finally:
            GPIO.output(BUZZER_PIN, GPIO.LOW)

    # =============================
    # WHEEL SENSOR (FIXED)
    # =============================
    def is_hands_on_wheel(self) -> bool:

        if not self.gpio_enabled:
            return True

        readings = []

        for _ in range(WHEEL_DEBOUNCE_READS):

            # IMPORTANT:
            # With pull-up resistors:
            # HIGH = not pressed
            # LOW = pressed (hand on wheel / conductive contact)
            s1 = GPIO.input(WHEEL_SENSOR_PINS[0]) == GPIO.LOW
            s2 = GPIO.input(WHEEL_SENSOR_PINS[1]) == GPIO.LOW

            readings.append(s1 or s2)

            time.sleep(WHEEL_DEBOUNCE_DELAY)

        # Majority voting (stable + real-world safe)
        return sum(readings) >= (len(readings) / 2)

    # =============================
    # CLEANUP
    # =============================
    def cleanup(self):

        if not self.gpio_enabled:
            return

        GPIO.output(BUZZER_PIN, GPIO.LOW)
        GPIO.cleanup()
        logger.info("GPIO cleanup complete")