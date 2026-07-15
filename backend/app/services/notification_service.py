"""
Wraps Firebase Cloud Messaging (FCM) HTTP v1 push notifications for caregiver alerts,
and provides SMTP email backup fallback.
"""
import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import requests


def send_caregiver_alert(app, caregiver: dict, user_name: str, message: str, lat: float, lng: float, emergency_id: str, timestamp) -> bool:
    """
    Sends a push notification to the caregiver's registered device token.
    Returns True if the notification was accepted by FCM, False otherwise.
    """
    fcm_key = app.config.get("FCM_SERVER_KEY")
    fcm_token = caregiver.get("fcm_token")

    if not fcm_key or not fcm_token:
        # No push channel available - return False to trigger email backup fallback
        app.logger.warning("FCM server key or caregiver FCM token is missing.")
        return False

    maps_link = f"https://www.google.com/maps?q={lat},{lng}"
    
    # Requirement: Title is "🚨 Emergency Alert"
    # Body is "The user requires immediate assistance. Tap to open the current location."
    # Payload includes: Emergency ID, Timestamp, Google Maps URL
    payload = {
        "to": fcm_token,
        "notification": {
            "title": "🚨 Emergency Alert",
            "body": "The user requires immediate assistance. Tap to open the current location.",
        },
        "data": {
            "type": "emergency",
            "emergency_id": str(emergency_id),
            "timestamp": str(timestamp),
            "google_maps_url": maps_link,
            "latitude": str(lat),
            "longitude": str(lng),
            "message": message,
        },
    }
    headers = {
        "Authorization": f"key={fcm_key}",
        "Content-Type": "application/json",
    }
    try:
        resp = requests.post(
            "https://fcm.googleapis.com/fcm/send",
            json=payload,
            headers=headers,
            timeout=5,
        )
        return resp.status_code == 200
    except requests.RequestException as e:
        app.logger.error(f"FCM request failed: {e}")
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

