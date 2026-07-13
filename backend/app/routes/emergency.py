"""
Emergency SOS endpoints: log emergency, notify caregiver via FCM, store location.
"""
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from datetime import datetime, timezone

from app.services.notification_service import send_caregiver_alert

emergency_bp = Blueprint("emergency", __name__)


@emergency_bp.route("/sos", methods=["POST"])
def trigger_sos():
    """
    Body: { user_id, latitude, longitude, message? }
    1. Stores an emergency log.
    2. Looks up the user's caregiver contact + FCM token.
    3. Sends a push notification with the user's location.
    """
    data = request.get_json(force=True)
    user_id = data.get("user_id")
    lat = data.get("latitude")
    lng = data.get("longitude")
    message = data.get("message", "Emergency! I need help immediately.")

    if not user_id or lat is None or lng is None:
        return jsonify({"error": "user_id, latitude, longitude are required"}), 400

    user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    if not user:
        return jsonify({"error": "User not found"}), 404

    log_doc = {
        "user_id": ObjectId(user_id),
        "message": message,
        "location": {"type": "Point", "coordinates": [lng, lat]},
        "caregiver_notified": False,
        "timestamp": datetime.now(timezone.utc),
    }
    result = current_app.db.emergency_logs.insert_one(log_doc)

    caregiver = user.get("caregiver", {})
    notified = send_caregiver_alert(
        current_app,
        caregiver=caregiver,
        user_name=user.get("name", "A TouchSpeak user"),
        message=message,
        lat=lat,
        lng=lng,
    )

    current_app.db.emergency_logs.update_one(
        {"_id": result.inserted_id}, {"$set": {"caregiver_notified": notified}}
    )

    return jsonify({
        "message": "SOS triggered",
        "log_id": str(result.inserted_id),
        "caregiver_notified": notified,
    }), 200


@emergency_bp.route("/logs/<user_id>", methods=["GET"])
def get_logs(user_id):
    docs = list(
        current_app.db.emergency_logs
        .find({"user_id": ObjectId(user_id)})
        .sort("timestamp", -1)
    )
    for d in docs:
        d["_id"] = str(d["_id"])
        d["user_id"] = str(d["user_id"])
    return jsonify(docs), 200
