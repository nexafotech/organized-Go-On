import json
import logging
import os
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from app.models.notification import DeviceToken, NotificationLog, NotificationDeliveryStatus

logger = logging.getLogger(__name__)

# Firebase Admin SDK initialization state
_firebase_initialized = False
_firebase_app = None


def get_firebase_app():
    """
    Lazily initialize Firebase Admin SDK if credentials exist.
    Looks for:
      1. FIREBASE_CREDENTIALS_PATH (path to serviceAccountKey.json)
      2. GOOGLE_APPLICATION_CREDENTIALS (path to serviceAccountKey.json)
      3. FIREBASE_CREDENTIALS_JSON (raw JSON string)
    """
    global _firebase_initialized, _firebase_app
    if _firebase_initialized:
        return _firebase_app

    cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH") or os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")

    try:
        import firebase_admin
        from firebase_admin import credentials

        if cred_path and os.path.exists(cred_path):
            cred = credentials.Certificate(cred_path)
            _firebase_app = firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK successfully initialized from certificate path: %s", cred_path)
        elif cred_json:
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
            _firebase_app = firebase_admin.initialize_app(cred)
            _firebase_initialized = True
            logger.info("Firebase Admin SDK successfully initialized from JSON string environment variable")
        else:
            logger.info("No Firebase credentials provided. FCM service operating in mock/simulated dispatch mode.")
            _firebase_initialized = True
            _firebase_app = None
    except Exception as exc:
        logger.warning("Could not initialize Firebase Admin SDK: %s. Using mock/simulated dispatch mode.", exc)
        _firebase_initialized = True
        _firebase_app = None

    return _firebase_app


class FCMService:
    @staticmethod
    def send_push_to_token(
        db: Session,
        token: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        channel_id: str = "GO_ON_GENERAL",
        high_importance: bool = False,
    ) -> Dict[str, Any]:
        """
        Sends an FCM push notification to a single device token.
        Deactivates stale/invalid tokens if FCM rejects them.
        """
        data = data or {}
        # Ensure data payload values are all strings for FCM
        str_data = {str(k): str(v) for k, v in data.items()}

        app = get_firebase_app()
        if app is not None:
            try:
                from firebase_admin import messaging
                from firebase_admin.exceptions import FirebaseError

                android_notification = messaging.AndroidNotification(
                    title=title,
                    body=body,
                    icon="ic_notification",
                    channel_id=channel_id,
                    priority="max" if high_importance else "default",
                    default_sound=True,
                    default_vibrate_timings=True,
                )

                android_config = messaging.AndroidConfig(
                    priority="high" if high_importance else "normal",
                    notification=android_notification,
                    data=str_data,
                )

                apns_config = messaging.ApnsConfig(
                    headers={
                        "apns-priority": "10" if high_importance else "5",
                    },
                    payload=messaging.ApsPayload(
                        aps=messaging.Aps(
                            alert=messaging.ApsAlert(
                                title=title,
                                body=body,
                            ),
                            sound="default",
                            badge=1,
                            content_available=True,
                        ),
                        custom_data=str_data,
                    ),
                )

                message = messaging.Message(
                    token=token,
                    notification=messaging.Notification(
                        title=title,
                        body=body,
                    ),
                    data=str_data,
                    android=android_config,
                    apns=apns_config,
                )

                response = messaging.send(message)
                logger.info("FCM push successfully delivered to token %s...: %s", token[:12], response)
                return {"success": True, "message_id": response, "simulated": False}

            except Exception as exc:
                err_str = str(exc)
                logger.warning("FCM push delivery failed for token %s...: %s", token[:12], err_str)
                # Check for token deactivation conditions
                if any(k in err_str.lower() for k in ["unregistered", "not found", "invalid_argument", "mismatch"]):
                    logger.info("Deactivating invalid FCM token in database: %s...", token[:12])
                    db.query(DeviceToken).filter(DeviceToken.token == token).update({"is_active": False})
                    db.commit()
                return {"success": False, "error": err_str, "simulated": False}

        # Simulated / development mode
        logger.info(
            "[SIMULATED FCM PUSH] Token: %s... | Channel: %s | Title: %s | Body: %s | Data: %s",
            token[:16] if token else "none",
            channel_id,
            title,
            body,
            str_data,
        )
        return {
            "success": True,
            "message_id": f"simulated-{os.urandom(6).hex()}",
            "simulated": True,
        }

    @staticmethod
    def send_push_to_user_devices(
        db: Session,
        user_id: int,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        channel_id: str = "GO_ON_GENERAL",
        high_importance: bool = False,
    ) -> List[Dict[str, Any]]:
        """
        Sends an FCM push notification to all active devices registered to a user.
        """
        active_tokens = (
            db.query(DeviceToken)
            .filter(DeviceToken.user_id == user_id, DeviceToken.is_active == True)
            .all()
        )
        results = []
        for dev in active_tokens:
            res = FCMService.send_push_to_token(
                db=db,
                token=dev.token,
                title=title,
                body=body,
                data=data,
                channel_id=channel_id,
                high_importance=high_importance,
            )
            results.append(res)
        return results
