import json
import logging
import os
import time
from typing import Dict, Any, List, Optional, Tuple, Set
from sqlalchemy.orm import Session
from app.models.notification import DeviceToken, NotificationDeliveryStatus

logger = logging.getLogger(__name__)

# Firebase Admin SDK initialization state
_firebase_initialized = False
_firebase_app = None

# FCM Maximum Multicast Batch Size according to Firebase specifications
FCM_BATCH_SIZE = 500


def get_firebase_app():
    """
    Lazily initialize Firebase Admin SDK if credentials exist.
    Looks for:
      1. FIREBASE_CREDENTIALS_PATH (path to serviceAccountKey.json)
      2. GOOGLE_APPLICATION_CREDENTIALS (path to serviceAccountKey.json)
      3. FIREBASE_CREDENTIALS_JSON (raw JSON string)
    If none are configured, defaults to mock/simulated dispatch mode.
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


def reset_firebase_app():
    """Reset Firebase Admin SDK state (used primarily in test fixtures)."""
    global _firebase_initialized, _firebase_app
    try:
        import firebase_admin
        if _firebase_app is not None:
            firebase_admin.delete_app(_firebase_app)
    except Exception:
        pass
    _firebase_initialized = False
    _firebase_app = None


def mask_token(token: Optional[str]) -> str:
    """Masks device tokens to protect credentials in log files."""
    if not token:
        return "<empty>"
    clean = token.strip()
    if len(clean) <= 12:
        return f"{clean[:4]}...***"
    return f"{clean[:6]}...{clean[-4:]}"


def is_token_unregistered_error(exc: Exception) -> bool:
    """
    Detects if an exception indicates a permanent token failure:
    e.g. UnregisteredError, SenderIdMismatchError, InvalidArgumentError,
    or unregistered/invalid token strings.
    """
    err_str = str(exc).lower()
    exc_type = type(exc).__name__.lower()

    permanent_keywords = [
        "unregistered",
        "registration-token-not-registered",
        "invalid-registration-token",
        "not found",
        "invalid_argument",
        "mismatch",
        "sender_id_mismatch",
        "senderidmismatch",
        "entity was not found",
    ]
    return any(k in err_str or k in exc_type for k in permanent_keywords)


def is_transient_error(exc: Exception) -> bool:
    """
    Detects if an exception indicates a transient failure suitable for retry:
    e.g. timeouts, rate limiting / quota, server unavailable, network resets.
    """
    err_str = str(exc).lower()
    exc_type = type(exc).__name__.lower()

    transient_keywords = [
        "unavailable",
        "deadline_exceeded",
        "deadline exceeded",
        "timeout",
        "timed out",
        "quota",
        "resource_exhausted",
        "too many requests",
        "internal",
        "connection reset",
    ]
    return any(k in err_str or k in exc_type for k in transient_keywords)


def sanitize_payload(
    title: str,
    body: str,
    data: Optional[Dict[str, Any]] = None,
) -> Tuple[str, str, Dict[str, str]]:
    """
    Sanitizes push notification contents according to FCM constraints:
    - Enforces title max length 200
    - Enforces body max length 1000
    - Ensures all data values are string key-value pairs
    """
    clean_title = (title or "").strip()[:200]
    clean_body = (body or "").strip()[:1000]

    raw_data = data or {}
    str_data: Dict[str, str] = {}
    for k, v in raw_data.items():
        if v is not None:
            str_data[str(k)] = str(v)

    # Check payload size constraint (FCM limits data payloads to 4096 bytes)
    try:
        encoded_len = len(json.dumps(str_data).encode("utf-8"))
        if encoded_len > 4000:
            logger.warning("FCM data payload size (%d bytes) is near or exceeds 4KB limit", encoded_len)
    except Exception:
        pass

    return clean_title, clean_body, str_data


def deactivate_tokens(db: Session, tokens: List[str]) -> int:
    """Deactivates invalid or unregistered tokens in the database."""
    if not tokens:
        return 0
    clean_tokens = [t.strip() for t in tokens if t and t.strip()]
    if not clean_tokens:
        return 0

    updated = (
        db.query(DeviceToken)
        .filter(DeviceToken.token.in_(clean_tokens), DeviceToken.is_active == True)
        .update({"is_active": False}, synchronize_session="fetch")
    )
    db.commit()
    db.expire_all()
    logger.info("Deactivated %d invalid FCM token(s): %s", updated, [mask_token(t) for t in clean_tokens[:5]])
    return updated


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
        max_retries: int = 2,
    ) -> Dict[str, Any]:
        """
        Sends an FCM push notification to a single device token.
        - Sanitizes payload
        - Retries on transient network/quota errors with exponential backoff
        - Immediately deactivates stale/invalid tokens on permanent FCM rejection
        """
        if not token or not token.strip():
            return {"success": False, "error": "Empty device token", "simulated": False}

        clean_token = token.strip()
        title, body, str_data = sanitize_payload(title, body, data)

        app = get_firebase_app()
        if app is not None:
            from firebase_admin import messaging

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

            apns_config = messaging.APNSConfig(
                headers={
                    "apns-priority": "10" if high_importance else "5",
                },
                payload=messaging.APNSPayload(
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
                token=clean_token,
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=str_data,
                android=android_config,
                apns=apns_config,
            )

            last_error = ""
            for attempt in range(max_retries + 1):
                try:
                    response = messaging.send(message)
                    logger.info("FCM push delivered to token %s: msg_id=%s", mask_token(clean_token), response)
                    return {"success": True, "message_id": response, "simulated": False}
                except Exception as exc:
                    last_error = str(exc)
                    if is_token_unregistered_error(exc):
                        logger.warning(
                            "Permanent FCM error for token %s: %s. Deactivating token.",
                            mask_token(clean_token),
                            last_error,
                        )
                        deactivate_tokens(db, [clean_token])
                        return {
                            "success": False,
                            "error": last_error,
                            "deactivated": True,
                            "simulated": False,
                        }

                    if is_transient_error(exc) and attempt < max_retries:
                        backoff = 0.5 * (attempt + 1)
                        logger.warning(
                            "Transient FCM error for token %s (attempt %d/%d): %s. Retrying in %.1fs...",
                            mask_token(clean_token),
                            attempt + 1,
                            max_retries,
                            last_error,
                            backoff,
                        )
                        time.sleep(backoff)
                        continue

                    logger.warning("FCM delivery failed for token %s: %s", mask_token(clean_token), last_error)
                    break

            return {"success": False, "error": last_error, "simulated": False}

        # Simulated / development mode
        logger.info(
            "[SIMULATED FCM PUSH] Token: %s | Channel: %s | Title: %s | Body: %s",
            mask_token(clean_token),
            channel_id,
            title,
            body,
        )
        return {
            "success": True,
            "message_id": f"simulated-{os.urandom(6).hex()}",
            "simulated": True,
        }

    @staticmethod
    def send_multicast_push(
        db: Session,
        tokens: List[str],
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
        channel_id: str = "GO_ON_GENERAL",
        high_importance: bool = False,
    ) -> Dict[str, Any]:
        """
        Sends an FCM multicast push notification to up to thousands of device tokens,
        automatically chunking into batches of 500 (FCM limits).
        - Deactivates invalid/expired tokens in bulk
        - Tracks sent vs failed count accurately
        """
        # Deduplicate and clean tokens
        unique_tokens = list(dict.fromkeys(t.strip() for t in tokens if t and t.strip()))
        if not unique_tokens:
            return {
                "total_tokens": 0,
                "sent_count": 0,
                "failed_count": 0,
                "deactivated_tokens": 0,
                "simulated": False,
                "message_ids": [],
            }

        title, body, str_data = sanitize_payload(title, body, data)
        app = get_firebase_app()

        if app is not None:
            from firebase_admin import messaging

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
            apns_config = messaging.APNSConfig(
                headers={"apns-priority": "10" if high_importance else "5"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(
                        alert=messaging.ApsAlert(title=title, body=body),
                        sound="default",
                        badge=1,
                        content_available=True,
                    ),
                    custom_data=str_data,
                ),
            )

            total_sent = 0
            total_failed = 0
            message_ids: List[str] = []
            tokens_to_deactivate: Set[str] = set()
            successful_tokens: List[str] = []
            failed_tokens: List[str] = []

            # Process in chunks of FCM_BATCH_SIZE (500)
            for i in range(0, len(unique_tokens), FCM_BATCH_SIZE):
                chunk = unique_tokens[i : i + FCM_BATCH_SIZE]
                multicast_message = messaging.MulticastMessage(
                    tokens=chunk,
                    notification=messaging.Notification(title=title, body=body),
                    data=str_data,
                    android=android_config,
                    apns=apns_config,
                )

                try:
                    # send_each_for_multicast is recommended in firebase_admin >= 6.0
                    batch_response = messaging.send_each_for_multicast(multicast_message)
                except Exception as exc:
                    logger.error("Multicast send failed for batch of %d tokens: %s", len(chunk), exc)
                    total_failed += len(chunk)
                    failed_tokens.extend(chunk)
                    continue

                for idx, resp in enumerate(batch_response.responses):
                    tok = chunk[idx]
                    if resp.success:
                        total_sent += 1
                        successful_tokens.append(tok)
                        if resp.message_id:
                            message_ids.append(resp.message_id)
                    else:
                        total_failed += 1
                        failed_tokens.append(tok)
                        if resp.exception and is_token_unregistered_error(resp.exception):
                            tokens_to_deactivate.add(tok)

            deactivated_count = 0
            if tokens_to_deactivate:
                deactivated_count = deactivate_tokens(db, list(tokens_to_deactivate))

            logger.info(
                "FCM Multicast completed: total=%d, sent=%d, failed=%d, deactivated=%d",
                len(unique_tokens),
                total_sent,
                total_failed,
                deactivated_count,
            )

            return {
                "total_tokens": len(unique_tokens),
                "sent_count": total_sent,
                "failed_count": total_failed,
                "deactivated_tokens": deactivated_count,
                "simulated": False,
                "message_ids": message_ids,
                "successful_tokens": successful_tokens,
                "failed_tokens": failed_tokens,
            }

        # Simulated / development mode
        logger.info(
            "[SIMULATED FCM MULTICAST] Tokens: %d | Channel: %s | Title: %s | Body: %s",
            len(unique_tokens),
            channel_id,
            title,
            body,
        )
        simulated_ids = [f"simulated-multicast-{os.urandom(4).hex()}" for _ in range(min(5, len(unique_tokens)))]
        return {
            "total_tokens": len(unique_tokens),
            "sent_count": len(unique_tokens),
            "failed_count": 0,
            "deactivated_tokens": 0,
            "simulated": True,
            "message_ids": simulated_ids,
            "successful_tokens": unique_tokens,
            "failed_tokens": [],
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
        Deduplicates tokens so no user device receives duplicate notifications.
        """
        active_tokens = (
            db.query(DeviceToken)
            .filter(DeviceToken.user_id == user_id, DeviceToken.is_active == True)
            .all()
        )
        # Deduplicate tokens
        seen_tokens = set()
        unique_tokens = []
        for dev in active_tokens:
            if dev.token and dev.token not in seen_tokens:
                seen_tokens.add(dev.token)
                unique_tokens.append(dev.token)

        results = []
        for token_str in unique_tokens:
            res = FCMService.send_push_to_token(
                db=db,
                token=token_str,
                title=title,
                body=body,
                data=data,
                channel_id=channel_id,
                high_importance=high_importance,
            )
            results.append(res)
        return results
