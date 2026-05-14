import logging
import threading
import time
from pathlib import Path

import firebase_admin
from firebase_admin import credentials, db

logger = logging.getLogger("ADAMS")

BASE_DIR = Path(__file__).resolve().parent
SERVICE_ACCOUNT_PATH = BASE_DIR / "serviceAccountKey.json"
DATABASE_URL = (
    "https://adams-system-a1998-default-rtdb.asia-southeast1."
    "firebasedatabase.app/"
)
SYNC_INTERVAL_SECONDS = 2


class CloudSync:

    def __init__(self):
        self.latest_data = {}
        self.firebase_enabled = False
        self.ref = None
        self.stop_event = threading.Event()
        self.thread = None

        try:
            if not SERVICE_ACCOUNT_PATH.exists():
                raise FileNotFoundError(f"Missing {SERVICE_ACCOUNT_PATH}")

            if not firebase_admin._apps:
                cred = credentials.Certificate(str(SERVICE_ACCOUNT_PATH))
                firebase_admin.initialize_app(cred, {
                    "databaseURL": DATABASE_URL
                })

            self.ref = db.reference("/driver_status")
            self.firebase_enabled = True
            logger.info("Firebase connected")

        except Exception as e:
            logger.error(f"Firebase connection failed: {e}")

    # =========================
    # UPDATE DATA
    # =========================

    def update_data(self, data):
        self.latest_data = data

    # =========================
    # FIREBASE THREAD
    # =========================

    def sync_loop(self):
        while not self.stop_event.is_set():
            try:
                if self.firebase_enabled and self.latest_data:
                    self.ref.update(self.latest_data)
                    logger.info("Firebase synced")

            except Exception as e:
                logger.error(f"Firebase sync failed: {e}")

            self.stop_event.wait(SYNC_INTERVAL_SECONDS)

    # =========================
    # START / STOP THREAD
    # =========================

    def start(self):
        if self.thread and self.thread.is_alive():
            return

        self.thread = threading.Thread(target=self.sync_loop, daemon=True)
        self.thread.start()

    def stop(self):
        self.stop_event.set()

        if self.thread and self.thread.is_alive():
            self.thread.join(timeout=SYNC_INTERVAL_SECONDS)
