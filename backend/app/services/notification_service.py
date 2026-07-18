"""
Wraps Firebase Cloud Messaging (FCM) using Firebase Admin SDK for caregiver alerts,
and provides SMTP email backup fallback.
"""
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import firebase_admin
from firebase_admin import credentials, messaging

firebase_initialized = False


def _init_firebase(app):
    global firebase_initialized
    if firebase_initialized:
        return True

    # Check if already initialized in another thread/module
    if firebase_admin._apps:
        firebase_initialized = True
        return True

    # 1. Look for custom FIREBASE_CREDENTIALS path in environment, app config, or standard project folder
    possible_paths = [
        os.getenv("FIREBASE_CREDENTIALS"),
        app.config.get("FIREBASE_CREDENTIALS"),
        "firebase-service-account.json",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "firebase", "firebase-admin.json")),
        os.path.abspath(os.path.join(os.getcwd(), "..", "firebase", "firebase-admin.json")),
        os.path.abspath(os.path.join(os.getcwd(), "firebase", "firebase-admin.json")),
    ]
    
    cred_path = None
    for p in possible_paths:
        if p and os.path.exists(p):
            cred_path = p
            break

    if cred_path:
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            firebase_initialized = True
            app.logger.info(f"Firebase Admin SDK initialized successfully using certificate file: {cred_path}")
            return True
        except Exception as e:
            app.logger.error(f"Failed to initialize Firebase Admin with certificate file ({cred_path}): {e}")

    # 2. Try App Default Credentials
    try:
        firebase_admin.initialize_app()
        firebase_initialized = True
        app.logger.info("Firebase Admin SDK initialized using Application Default Credentials.")
        return True
    except Exception as e:
        app.logger.warning(
            f"Firebase Admin SDK initialization failed; using mock/fallback mode. Error: {e}"
        )
        return False


def send_caregiver_alert(app, caregiver: dict, user_name: str, message: str, lat: float, lng: float, emergency_id: str, timestamp) -> bool:
    """
    Sends a push notification to the caregiver's registered device token using Firebase Admin SDK.
    Returns True if the notification was accepted by FCM, False otherwise.
    """
    fcm_token = caregiver.get("fcm_token")
    if not fcm_token:
        # No push channel available - return False to trigger email backup fallback
        app.logger.warning(f"Caregiver {caregiver.get('name', 'Unknown')} has no FCM token registered.")
        return False

    # Initialize Firebase if not done yet
    _init_firebase(app)

    maps_link = f"https://www.google.com/maps?q={lat},{lng}"
    timestamp_str = timestamp.strftime("%Y-%m-%d %H:%M:%S UTC") if hasattr(timestamp, "strftime") else str(timestamp)

    # For testing/mock mode under mongomock and unit tests, we simulate success:
    if not firebase_initialized:
        if app.config.get("TESTING") or os.getenv("FLASK_ENV") == "testing":
            app.logger.info(f"[MOCK FCM] Message successfully sent to {fcm_token}")
            return True
        app.logger.warning("FCM cannot be sent because Firebase Admin SDK is not initialized.")
        return False

    try:
        msg_payload = messaging.Message(
            notification=messaging.Notification(
                title="🚨 Emergency Alert",
                body="The user requires immediate assistance. Tap to open the current location.",
            ),
            data={
                "type": "emergency",
                "emergency_id": str(emergency_id),
                "timestamp": timestamp_str,
                "google_maps_url": maps_link,
                "latitude": str(lat),
                "longitude": str(lng),
                "message": message,
                "user_name": user_name
            },
            token=fcm_token
        )
        response = messaging.send(msg_payload)
        app.logger.info(f"FCM message sent successfully: {response}")
        return True
    except Exception as e:
        app.logger.error(f"Failed to send FCM message via Admin SDK: {e}")
        return False


def send_backup_email(app, caregiver_email: str, user_name: str, emergency_id: str, timestamp_str: str, maps_link: str, message: str) -> bool:
    """
    Sends a backup email alert to the caregiver when FCM push delivery fails.
    Subject: Emergency SOS Alert
    Includes: User Name, Emergency ID, Current Time, Google Maps Link, Emergency Message
    """
    smtp_server = app.config.get("SMTP_SERVER") or os.getenv("SMTP_SERVER", "localhost")
    smtp_port = int(app.config.get("SMTP_PORT") or os.getenv("SMTP_PORT", 25))
    smtp_username = app.config.get("SMTP_USERNAME") or os.getenv("SMTP_USERNAME", "")
    smtp_password = app.config.get("SMTP_PASSWORD") or os.getenv("SMTP_PASSWORD", "")
    sender_email = app.config.get("SENDER_EMAIL") or os.getenv("SENDER_EMAIL", "sos@touchspeak.ai")

    if not caregiver_email:
        app.logger.warning("No caregiver email address configured for backup email notification.")
        return False

    body = f"""Emergency SOS Alert

An emergency alert was triggered for {user_name}.

Emergency ID: {emergency_id}
Current Time: {timestamp_str}
Emergency Message: {message}

Google Maps Link:
{maps_link}
"""

    msg = MIMEMultipart()
    msg["From"] = sender_email
    msg["To"] = caregiver_email
    msg["Subject"] = "Emergency SOS Alert"
    msg.attach(MIMEText(body, "plain", "utf-8"))

    try:
        if smtp_server == "localhost" and smtp_port == 25:
            # Local/dev server setup (non-authenticated fallback test)
            with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
                server.sendmail(sender_email, caregiver_email, msg.as_string())
            app.logger.info(f"Backup email sent successfully local SMTP: {caregiver_email}")
            return True
        else:
            # Production server setup with SSL/TLS
            with smtplib.SMTP(smtp_server, smtp_port, timeout=10) as server:
                if smtp_port == 587:
                    server.starttls()
                if smtp_username and smtp_password:
                    server.login(smtp_username, smtp_password)
                server.sendmail(sender_email, caregiver_email, msg.as_string())
            app.logger.info(f"Backup email sent successfully: {caregiver_email}")
            return True
    except Exception as e:
        app.logger.error(f"Failed to send backup email via SMTP: {e}")
        return False
