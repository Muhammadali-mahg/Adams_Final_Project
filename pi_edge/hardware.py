"""
hardware.py – improved version

Changes vs original:
- buzz_alert() now accepts a severity level (DISTRACTED / DIZZY / DROWSY)
  and plays a different buzz pattern per state — all using lightweight
  GPIO pulses, no audio libraries needed on the Pi.
- Wheel sensor is debounced (3 consecutive reads) to avoid false OFF
  readings from vibration.
- Buzzer is always driven LOW on startup to prevent stuck-on state after
  an unclean shutdown.
- cleanup() now turns off buzzer explicitly even if it was somehow left HIGH.
"""

import logging
import time

try:
    import RPi.GPIO as GPIO
except (ImportError, RuntimeError):
    GPIO = None

logger = logging.getLogger("ADAMS")

# Pin config
BUZZER_PIN = 17
WHEEL_SENSOR_PIN = 27

# Buzz cooldown — minimum seconds between any alert
BUZZ_COOLDOWN_SECONDS = 2

# Debounce: how many consecutive reads must agree for wheel sensor
WHEEL_DEBOUNCE_READS = 3
WHEEL_DEBOUNCE_DELAY = 0.01  # 10 ms between reads

# Buzz patterns per driver state: list of (on_seconds, off_seconds) pulses
# Keeps it lightweight — no PWM, no audio lib, just GPIO toggling
BUZZ_PATTERNS = {
    "DISTRACTED": [(0.15, 0.10), (0.15, 0.10)],          # two short beeps
    "DIZZY":      [(0.25, 0.10), (0.25, 0.10), (0.25, 0.10)],  # three medium
    "DROWSY":     [(0.60, 0.10), (0.60, 0.00)],           # two long pulses
    "DEFAULT":    [(0.30, 0.00)],                          # single beep
}


class HardwareController:

    def __init__(self):
        self.last_buzz_time = 0.0
        self.gpio_enabled = GPIO is not None
        self._wheel_history: list[bool] = []

        if not self.gpio_enabled:
            logger.warning(
                "GPIO unavailable – HardwareController running in simulation mode"
            )
            return

        GPIO.setwarnings(False)
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(BUZZER_PIN, GPIO.OUT)
        GPIO.setup(WHEEL_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_DOWN)

        # Always start with buzzer off (guards against dirty shutdown)
        GPIO.output(BUZZER_PIN, GPIO.LOW)
        logger.info("GPIO initialised (BCM mode)")

    # ------------------------------------------------------------------
    # Buzzer
    # ------------------------------------------------------------------

    def buzz_alert(self, state: str = "DEFAULT") -> None:
        """
        Fire a buzz pattern matching *state*.
        Respects BUZZ_COOLDOWN_SECONDS between calls.
        """
        now = time.time()
        if now - self.last_buzz_time < BUZZ_COOLDOWN_SECONDS:
            return

        pattern = BUZZ_PATTERNS.get(state, BUZZ_PATTERNS["DEFAULT"])
        logger.warning(f"Buzzer alert: {state} pattern ({len(pattern)} pulse(s))")

        self.last_buzz_time = now   # stamp before blocking so cooldown is clean

        if not self.gpio_enabled:
            return  # simulation: log only

        try:
            for on_time, off_time in pattern:
                GPIO.output(BUZZER_PIN, GPIO.HIGH)
                time.sleep(on_time)
                GPIO.output(BUZZER_PIN, GPIO.LOW)
                if off_time > 0:
                    time.sleep(off_time)
        except Exception as e:
            logger.error(f"Buzzer error: {e}")
        finally:
            # Always ensure buzzer ends LOW
            GPIO.output(BUZZER_PIN, GPIO.LOW)

    # ------------------------------------------------------------------
    # Wheel sensor (debounced)
    # ------------------------------------------------------------------

    def is_hands_on_wheel(self) -> bool:
        """
        Return True if the wheel sensor reads HIGH.
        Uses WHEEL_DEBOUNCE_READS consecutive reads to filter vibration noise.
        Simulation mode always returns True (safe default).
        """
        if not self.gpio_enabled:
            return True

        readings: list[bool] = []
        for _ in range(WHEEL_DEBOUNCE_READS):
            readings.append(GPIO.input(WHEEL_SENSOR_PIN) == GPIO.HIGH)
            time.sleep(WHEEL_DEBOUNCE_DELAY)

        # All reads must agree; if split, keep last known state or default True
        if all(readings):
            return True
        if not any(readings):
            return False

        # Ambiguous — safe default is True to avoid false alerts
        return True

    # ------------------------------------------------------------------
    # Cleanup
    # ------------------------------------------------------------------

    def cleanup(self) -> None:
        if not self.gpio_enabled:
            return

        try:
            GPIO.output(BUZZER_PIN, GPIO.LOW)
        except Exception:
            pass

        GPIO.cleanup()
        logger.info("GPIO cleanup complete")