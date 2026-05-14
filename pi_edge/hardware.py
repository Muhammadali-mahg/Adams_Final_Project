import logging
import time

try:
    import RPi.GPIO as GPIO
except (ImportError, RuntimeError):
    GPIO = None

logger = logging.getLogger("ADAMS")

BUZZER_PIN = 17
WHEEL_SENSOR_PIN = 27
BUZZ_INTERVAL_SECONDS = 2
BUZZ_DURATION_SECONDS = 0.5


class HardwareController:
    def __init__(self):
        self.last_buzz_time = 0
        self.gpio_enabled = GPIO is not None

        if not self.gpio_enabled:
            logger.warning("GPIO unavailable; running hardware controller in simulation mode")
            return

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(BUZZER_PIN, GPIO.OUT)
        GPIO.setup(WHEEL_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)
        GPIO.output(BUZZER_PIN, GPIO.LOW)

    def buzz_alert(self):
        current_time = time.time()

        if current_time - self.last_buzz_time < BUZZ_INTERVAL_SECONDS:
            return

        logger.warning("Buzzer alert activated")

        if self.gpio_enabled:
            GPIO.output(BUZZER_PIN, GPIO.HIGH)
            time.sleep(BUZZ_DURATION_SECONDS)
            GPIO.output(BUZZER_PIN, GPIO.LOW)

        self.last_buzz_time = current_time

    def is_hands_on_wheel(self):
        if not self.gpio_enabled:
            return True

        return GPIO.input(WHEEL_SENSOR_PIN) == GPIO.HIGH

    def cleanup(self):
        if not self.gpio_enabled:
            return

        GPIO.output(BUZZER_PIN, GPIO.LOW)
        GPIO.cleanup()
        logger.info("GPIO cleanup complete")
