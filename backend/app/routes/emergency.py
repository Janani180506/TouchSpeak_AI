"""
Emergency SOS endpoints: log emergency, notify caregiver via FCM, store location.
"""
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from datetime import datetime, timezone

from app.services.notification_service import send_caregiver_alert, send_backup_email

emergency_bp = Blueprint("emergency", __name__)


@emergency_bp.route("/sos", methods=["POST"])
def trigger_sos():
    """
    Body: { user_id, latitude, longitude, message? }
    1. Stores an emergency log with all required fields.
    2. Looks up the user's caregiver contact + FCM token.
    3. Sends a push notification.
    4. If FCM fails, sends SMTP backup email.
    5. Returns details in JSON response for Flutter UI display.
    """
    data = request.get_json(force=True)
    user_id = data.get("user_id")
    lat = data.get("latitude")
    lng = data.get("longitude")
    message = data.get("message", "Emergency! I need immediate assistance.")

    if not user_id or lat is None or lng is None:
        return jsonify({"error": "user_id, latitude, longitude are required"}), 400

    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID or MongoDB error: {e}"}), 400

    if not user:
        return jsonify({"error": "User not found"}), 404

    caregiver = user.get("caregiver", {})
    caregiver_name = caregiver.get("name", "Unknown Caregiver")
    maps_url = f"https://www.google.com/maps?q={lat},{lng}"
    now = datetime.now(timezone.utc)

    # Insert initial log document in MongoDB
    log_doc = {
        "user_id": ObjectId(user_id),
        "latitude": float(lat),
        "longitude": float(lng),
        "google_maps_url": maps_url,
        "timestamp": now,
        "caregiver_name": caregiver_name,
        "notification_status": "Pending",
        "email_status": "Pending",
        "message": message,
    }
    result = current_app.db.emergency_logs.insert_one(log_doc)
    log_id = str(result.inserted_id)

    # 1. Try Firebase Cloud Messaging (FCM)
    fcm_success = send_caregiver_alert(
        current_app,
        caregiver=caregiver,
        user_name=user.get("name", "A TouchSpeak user"),
        message=message,
        lat=lat,
        lng=lng,
        emergency_id=log_id,
        timestamp=now,
    )
    notification_status = "Success" if fcm_success else "Failed"

    # 2. Try Email Backup if FCM fails
    email_status = "Not Sent"
    if not fcm_success:
        caregiver_email = caregiver.get("email")
        email_success = send_backup_email(
            current_app,
            caregiver_email=caregiver_email,
            user_name=user.get("name", "A TouchSpeak user"),
            emergency_id=log_id,
            timestamp_str=now.strftime("%Y-%m-%d %H:%M:%S UTC"),
            maps_link=maps_url,
            message=message,
        )
        email_status = "Success" if email_success else "Failed"

    # Update MongoDB with final status
    current_app.db.emergency_logs.update_one(
        {"_id": result.inserted_id},
        {
            "$set": {
                "notification_status": notification_status,
                "email_status": email_status,
            }
        },
    )

    return jsonify({
        "message": "SOS triggered successfully",
        "log_id": log_id,
        "timestamp": now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        "caregiver_name": caregiver_name,
        "notification_status": notification_status,
        "email_status": email_status,
        "google_maps_url": maps_url,
    }), 200


@emergency_bp.route("/logs/<user_id>", methods=["GET"])
def get_logs(user_id):
    try:
        docs = list(
            current_app.db.emergency_logs
            .find({"user_id": ObjectId(user_id)})
            .sort("timestamp", -1)
        )
    except Exception as e:
        return jsonify({"error": f"Invalid User ID or MongoDB error: {e}"}), 400

    for d in docs:
        d["_id"] = str(d["_id"])
        d["user_id"] = str(d["user_id"])
        # Format timestamp for consistent reading in flutter/json
        if isinstance(d.get("timestamp"), datetime):
            d["timestamp"] = d["timestamp"].strftime("%Y-%m-%d %H:%M:%S UTC")
    return jsonify(docs), 200

