import firebase_admin
from firebase_admin import credentials, db

import threading
import time
import logging

logger = logging.getLogger("ADAMS")

class CloudSync:

    def __init__(self):

        self.latest_data = {}

        self.firebase_enabled = False

        try:

            cred = credentials.Certificate(
                "serviceAccountKey.json"
            )

            firebase_admin.initialize_app(cred, {
                'databaseURL':
                'https://adams-system-a1998-default-rtdb.asia-southeast1.firebasedatabase.app/'
            })

            self.ref = db.reference('/driver_status')

            self.firebase_enabled = True

            logger.info("☁️ Firebase connected")

        except Exception as e:

            logger.error(
                f"Firebase connection failed: {e}"
            )

    # =========================
    # UPDATE LOCAL DATA
    # =========================

    def update_data(self, data):

        self.latest_data = data

    # =========================
    # FIREBASE THREAD
    # =========================

    def sync_loop(self):

        while True:

            if self.firebase_enabled:

                try:

                    self.ref.update(
                        self.latest_data
                    )

                    logger.info(
                        "☁️ Firebase synced"
                    )

                except Exception as e:

                    logger.error(
                        f"Firebase sync failed: {e}"
                    )

            time.sleep(2)

    # =========================
    # START THREAD
    # =========================

    def start(self):

        thread = threading.Thread(
            target=self.sync_loop,
            daemon=True
        )

        thread.start()