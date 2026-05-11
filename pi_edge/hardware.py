from gpiozero import Buzzer, DigitalInputDevice
import time
import logging

logger = logging.getLogger("ADAMS")

# =========================
# GPIO DEVICES
# =========================

BUZZER_PIN = 17
FSR_PIN = 27

buzzer = Buzzer(BUZZER_PIN)

# FSR sensor
seat_sensor = DigitalInputDevice(FSR_PIN)

# =========================
# HARDWARE CLASS
# =========================

class HardwareController:

    def __init__(self):
        self.last_buzz_time = 0

    def buzz_alert(self):

        current_time = time.time()

        # Prevent spam buzzing
        if current_time - self.last_buzz_time < 2:
            return

        logger.warning("🚨 BUZZER ALERT ACTIVATED")

        buzzer.on()
        time.sleep(0.5)
        buzzer.off()

        self.last_buzz_time = current_time

    def is_driver_seated(self):

        return seat_sensor.value == 1

    def cleanup(self):

        buzzer.off()

        logger.info("GPIO cleaned up.")