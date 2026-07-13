"""
Wraps Firebase Cloud Messaging (FCM) HTTP v1 push notifications for caregiver alerts.
"""
import requests


def send_caregiver_alert(app, caregiver: dict, user_name: str, message: str, lat: float, lng: float) -> bool:
    """
    Sends a push notification to the caregiver's registered device token.
    Returns True if the notification was accepted by FCM, False otherwise
    (e.g. no server key configured, or caregiver has no fcm_token yet -
    in that case, an SMS/email fallback should be added in production).
    """
    fcm_key = app.config.get("FCM_SERVER_KEY")
    fcm_token = caregiver.get("fcm_token")

    if not fcm_key or not fcm_token:
        # No push channel available - in production, fall back to SMS (e.g. Twilio)
        # or email using caregiver.get("phone") / caregiver.get("email").
        return False

    maps_link = f"https://www.google.com/maps?q={lat},{lng}"
    payload = {
        "to": fcm_token,
        "notification": {
            "title": f"Emergency Alert from {user_name}",
            "body": f"{message} Location: {maps_link}",
        },
        "data": {
            "type": "emergency",
            "latitude": str(lat),
            "longitude": str(lng),
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
    except requests.RequestException:
        return False
