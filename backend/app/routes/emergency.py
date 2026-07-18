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
    2. Looks up all user's registered caregivers.
    3. For every caregiver who has notifications enabled:
       - Sends a push notification using Firebase Admin SDK.
       - If FCM fails, sends SMTP backup email.
    4. Continues to next caregiver even on failures.
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

    # Fetch multiple caregivers from 'caregivers' array
    caregivers = user.get("caregivers", [])
    
    # Fallback to single legacy caregiver structure if list is empty
    legacy_caregiver = user.get("caregiver", {})
    if not caregivers and legacy_caregiver and legacy_caregiver.get("name"):
        caregivers = [{
            "_id": "legacy",
            "name": legacy_caregiver.get("name"),
            "relationship": "Caregiver",
            "phone": legacy_caregiver.get("phone", ""),
            "email": legacy_caregiver.get("email", ""),
            "profile_photo": "",
            "fcm_token": legacy_caregiver.get("fcm_token", ""),
            "notifications_enabled": True
        }]

    maps_url = f"https://www.google.com/maps?q={lat},{lng}"
    now = datetime.now(timezone.utc)
    user_name = user.get("name", "A TouchSpeak user")

    # Insert initial emergency log document in MongoDB
    log_doc = {
        "user_id": ObjectId(user_id),
        "latitude": float(lat),
        "longitude": float(lng),
        "google_maps_url": maps_url,
        "timestamp": now,
        "message": message,
        "alert_status": "Sent",
        "caregiver_notifications": []
    }
    
    result = current_app.db.emergency_logs.insert_one(log_doc)
    log_id = str(result.inserted_id)

    # Process notification delivery for each caregiver
    caregiver_statuses = []
    
    for cg in caregivers:
        cg_id = cg.get("_id", "unknown")
        cg_name = cg.get("name", "Unknown Caregiver")
        cg_email = cg.get("email")
        cg_fcm = cg.get("fcm_token")
        notifications_enabled = cg.get("notifications_enabled", True)

        fcm_success = False
        email_success = False

        if notifications_enabled:
            # 1. Try Firebase Cloud Messaging (FCM)
            if cg_fcm:
                fcm_success = send_caregiver_alert(
                    current_app,
                    caregiver=cg,
                    user_name=user_name,
                    message=message,
                    lat=lat,
                    lng=lng,
                    emergency_id=log_id,
                    timestamp=now,
                )
            
            # 2. Try Email Backup if FCM fails
            if not fcm_success and cg_email:
                email_success = send_backup_email(
                    current_app,
                    caregiver_email=cg_email,
                    user_name=user_name,
                    emergency_id=log_id,
                    timestamp_str=now.strftime("%Y-%m-%d %H:%M:%S UTC"),
                    maps_link=maps_url,
                    message=message,
                )

        cg_status = {
            "caregiver_id": cg_id,
            "name": cg_name,
            "notification_status": "Success" if fcm_success else ("Failed" if cg_fcm else "Skipped"),
            "email_status": "Success" if email_success else ("Failed" if (cg_email and not fcm_success) else "Skipped"),
            "status": "Sent"
        }
        caregiver_statuses.append(cg_status)

    # Update MongoDB with final caregiver notifications status list
    current_app.db.emergency_logs.update_one(
        {"_id": result.inserted_id},
        {
            "$set": {
                "caregiver_notifications": caregiver_statuses,
            }
        },
    )

    # Root-level backward compatibility values
    primary_fcm = "Success" if any(s["notification_status"] == "Success" for s in caregiver_statuses) else "Failed"
    primary_email = "Success" if any(s["email_status"] == "Success" for s in caregiver_statuses) else "Skipped"
    primary_name = caregivers[0]["name"] if caregivers else "Unknown Caregiver"

    return jsonify({
        "message": "SOS triggered successfully",
        "log_id": log_id,
        "timestamp": now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        "caregiver_name": primary_name,
        "notification_status": primary_fcm,
        "email_status": primary_email,
        "google_maps_url": maps_url,
        "caregiver_statuses": caregiver_statuses
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


@emergency_bp.route("/alerts/<user_id>", methods=["GET"])
def get_alerts(user_id):
    """
    Fetches detailed emergency alerts for caregivers dashboard
    """
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
        user_name = user.get("name", "Unknown User") if user else "Unknown User"
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
        d["user_name"] = user_name
        if isinstance(d.get("timestamp"), datetime):
            d["timestamp"] = d["timestamp"].strftime("%Y-%m-%d %H:%M:%S UTC")
    return jsonify(docs), 200


@emergency_bp.route("/alerts/<alert_id>/status", methods=["PUT"])
def update_alert_status(alert_id):
    """
    Updates the Alert Status (Sent, Delivered, Viewed, Acknowledged, Resolved)
    """
    data = request.get_json(force=True)
    status = data.get("status")
    caregiver_id = data.get("caregiver_id")

    if not status:
        return jsonify({"error": "status is required"}), 400

    allowed_statuses = ["Sent", "Delivered", "Viewed", "Acknowledged", "Resolved"]
    if status not in allowed_statuses:
        return jsonify({"error": f"status must be one of {allowed_statuses}"}), 400

    try:
        alert = current_app.db.emergency_logs.find_one({"_id": ObjectId(alert_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid Alert ID: {e}"}), 400

    if not alert:
        return jsonify({"error": "Alert log not found"}), 404

    update_query = {"$set": {"alert_status": status}}

    if caregiver_id:
        notifications = alert.get("caregiver_notifications", [])
        updated_notifications = []
        for cn in notifications:
            if cn.get("caregiver_id") == caregiver_id:
                cn["status"] = status
            updated_notifications.append(cn)
        update_query["$set"]["caregiver_notifications"] = updated_notifications
    else:
        notifications = alert.get("caregiver_notifications", [])
        for cn in notifications:
            cn["status"] = status
        update_query["$set"]["caregiver_notifications"] = notifications

    current_app.db.emergency_logs.update_one(
        {"_id": ObjectId(alert_id)},
        update_query
    )

    return jsonify({"message": "Alert status updated successfully"}), 200


@emergency_bp.route("/web-config", methods=["GET"])
def get_web_config():
    import os
    from dotenv import load_dotenv
    load_dotenv(override=True)
    return jsonify({
        "apiKey": os.getenv("FIREBASE_API_KEY", ""),
        "authDomain": os.getenv("FIREBASE_AUTH_DOMAIN", ""),
        "projectId": os.getenv("FIREBASE_PROJECT_ID", "touchspeakai"),
        "storageBucket": os.getenv("FIREBASE_STORAGE_BUCKET", ""),
        "messagingSenderId": os.getenv("FIREBASE_MESSAGING_SENDER_ID", "115581064322107031468"),
        "appId": os.getenv("FIREBASE_APP_ID", ""),
        "measurementId": os.getenv("FIREBASE_MEASUREMENT_ID", "")
    }), 200
