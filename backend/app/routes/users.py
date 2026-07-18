"""
User profile & caregiver management endpoints.
"""
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from datetime import datetime, timezone

users_bp = Blueprint("users", __name__)


def serialize_user(doc):
    doc["_id"] = str(doc["_id"])
    return doc


@users_bp.route("", methods=["POST"])
def create_user():
    """
    Create a new user profile.
    Body: { name, age, preferred_language, caregiver: {name, phone, email}, emergency_contacts: [...] }
    """
    data = request.get_json(force=True)
    required = ["name", "preferred_language"]
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"error": f"Missing fields: {missing}"}), 400

    user_doc = {
        "name": data["name"],
        "age": data.get("age"),
        "preferred_language": data.get("preferred_language", "en"),
        "caregiver": data.get("caregiver", {}),
        "emergency_contacts": data.get("emergency_contacts", []),
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    result = current_app.db.users.insert_one(user_doc)
    user_doc["_id"] = result.inserted_id
    return jsonify(serialize_user(user_doc)), 201


@users_bp.route("/<user_id>", methods=["GET"])
def get_user(user_id):
    doc = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    if not doc:
        return jsonify({"error": "User not found"}), 404
    return jsonify(serialize_user(doc)), 200


@users_bp.route("/<user_id>", methods=["PUT"])
def update_user(user_id):
    data = request.get_json(force=True)
    data["updated_at"] = datetime.now(timezone.utc)
    result = current_app.db.users.update_one({"_id": ObjectId(user_id)}, {"$set": data})
    if result.matched_count == 0:
        return jsonify({"error": "User not found"}), 404
    return jsonify({"message": "User updated"}), 200


@users_bp.route("/<user_id>/preferences", methods=["PUT"])
def update_preferences(user_id):
    """Update per-user preferences (language, font size, icon layout, etc.)"""
    data = request.get_json(force=True)
    current_app.db.user_preferences.update_one(
        {"user_id": ObjectId(user_id)},
        {"$set": {**data, "updated_at": datetime.now(timezone.utc)}},
        upsert=True,
    )
    return jsonify({"message": "Preferences updated"}), 200


@users_bp.route("/<user_id>/preferences", methods=["GET"])
def get_preferences(user_id):
    doc = current_app.db.user_preferences.find_one({"user_id": ObjectId(user_id)})
    if not doc:
        return jsonify({"preferred_language": "en", "theme": "default"}), 200
    doc["_id"] = str(doc["_id"])
    doc["user_id"] = str(doc["user_id"])
    return jsonify(doc), 200


@users_bp.route("/<user_id>/caregivers", methods=["GET"])
def get_caregivers(user_id):
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID: {e}"}), 400
    if not user:
        return jsonify({"error": "User not found"}), 404
    caregivers = user.get("caregivers", [])
    legacy = user.get("caregiver", {})
    if not caregivers and legacy and legacy.get("name"):
        legacy_cg = {
            "_id": "legacy",
            "name": legacy.get("name"),
            "relationship": "Caregiver",
            "phone": legacy.get("phone", ""),
            "email": legacy.get("email", ""),
            "profile_photo": "",
            "fcm_token": legacy.get("fcm_token", ""),
            "notifications_enabled": True
        }
        caregivers = [legacy_cg]
    return jsonify(caregivers), 200


@users_bp.route("/<user_id>/caregivers", methods=["POST"])
def add_caregiver(user_id):
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID: {e}"}), 400
    if not user:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(force=True)
    required = ["name", "relationship", "phone", "email"]
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"error": f"Missing fields: {missing}"}), 400

    new_cg = {
        "_id": str(ObjectId()),
        "name": data["name"],
        "relationship": data["relationship"],
        "phone": data["phone"],
        "email": data["email"],
        "profile_photo": data.get("profile_photo", ""),
        "fcm_token": data.get("fcm_token", ""),
        "notifications_enabled": data.get("notifications_enabled", True)
    }

    current_app.db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$push": {"caregivers": new_cg}}
    )

    # Sync back to caregiver (legacy) if empty
    user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    if not user.get("caregiver") or not user.get("caregiver", {}).get("name"):
        current_app.db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "caregiver": {
                    "name": new_cg["name"],
                    "phone": new_cg["phone"],
                    "email": new_cg["email"],
                    "fcm_token": new_cg["fcm_token"]
                }
            }}
        )

    return jsonify(new_cg), 201


@users_bp.route("/<user_id>/caregivers/<caregiver_id>", methods=["PUT"])
def edit_caregiver(user_id, caregiver_id):
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID: {e}"}), 400
    if not user:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(force=True)
    caregivers = user.get("caregivers", [])
    found = False
    for cg in caregivers:
        if cg.get("_id") == caregiver_id or (caregiver_id == "legacy" and cg.get("_id") == "legacy"):
            found = True
            for field in ["name", "relationship", "phone", "email", "profile_photo", "fcm_token", "notifications_enabled"]:
                if field in data:
                    cg[field] = data[field]
            break

    if not found and caregiver_id == "legacy":
        legacy = user.get("caregiver", {})
        if legacy:
            new_cg = {
                "_id": "legacy",
                "name": data.get("name", legacy.get("name", "")),
                "relationship": data.get("relationship", "Caregiver"),
                "phone": data.get("phone", legacy.get("phone", "")),
                "email": data.get("email", legacy.get("email", "")),
                "profile_photo": data.get("profile_photo", ""),
                "fcm_token": data.get("fcm_token", legacy.get("fcm_token", "")),
                "notifications_enabled": data.get("notifications_enabled", True)
            }
            caregivers = [new_cg]
            found = True

    if not found:
        return jsonify({"error": "Caregiver not found"}), 404

    current_app.db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"caregivers": caregivers}}
    )

    if caregivers:
        first_cg = caregivers[0]
        current_app.db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "caregiver": {
                    "name": first_cg["name"],
                    "phone": first_cg["phone"],
                    "email": first_cg["email"],
                    "fcm_token": first_cg["fcm_token"]
                }
            }}
        )

    return jsonify({"message": "Caregiver updated"}), 200


@users_bp.route("/<user_id>/caregivers/<caregiver_id>", methods=["DELETE"])
def delete_caregiver(user_id, caregiver_id):
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID: {e}"}), 400
    if not user:
        return jsonify({"error": "User not found"}), 404

    caregivers = user.get("caregivers", [])
    new_caregivers = [cg for cg in caregivers if cg.get("_id") != caregiver_id and cg.get("_id") != "legacy"]

    current_app.db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"caregivers": new_caregivers}}
    )

    if new_caregivers:
        first_cg = new_caregivers[0]
        current_app.db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "caregiver": {
                    "name": first_cg["name"],
                    "phone": first_cg["phone"],
                    "email": first_cg["email"],
                    "fcm_token": first_cg["fcm_token"]
                }
            }}
        )
    else:
        current_app.db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {"caregiver": {}}}
        )

    return jsonify({"message": "Caregiver deleted"}), 200


@users_bp.route("/<user_id>/caregivers/<caregiver_id>/register-token", methods=["POST"])
def register_caregiver_token(user_id, caregiver_id):
    try:
        user = current_app.db.users.find_one({"_id": ObjectId(user_id)})
    except Exception as e:
        return jsonify({"error": f"Invalid User ID: {e}"}), 400
    if not user:
        return jsonify({"error": "User not found"}), 404

    data = request.get_json(force=True)
    fcm_token = data.get("fcm_token")
    if not fcm_token:
        return jsonify({"error": "fcm_token is required"}), 400

    caregivers = user.get("caregivers", [])
    updated = False
    for cg in caregivers:
        if cg.get("_id") == caregiver_id or (caregiver_id == "legacy" and cg.get("_id") == "legacy"):
            cg["fcm_token"] = fcm_token
            updated = True
            break

    if not updated and caregiver_id == "legacy":
        legacy = user.get("caregiver", {})
        new_cg = {
            "_id": "legacy",
            "name": legacy.get("name", "Legacy Caregiver"),
            "relationship": "Caregiver",
            "phone": legacy.get("phone", ""),
            "email": legacy.get("email", ""),
            "profile_photo": "",
            "fcm_token": fcm_token,
            "notifications_enabled": True
        }
        caregivers = [new_cg]
        updated = True

    if not updated:
        return jsonify({"error": "Caregiver not found"}), 404

    current_app.db.users.update_one(
        {"_id": ObjectId(user_id)},
        {"$set": {"caregivers": caregivers}}
    )

    if caregivers:
        first_cg = caregivers[0]
        current_app.db.users.update_one(
            {"_id": ObjectId(user_id)},
            {"$set": {
                "caregiver": {
                    "name": first_cg["name"],
                    "phone": first_cg["phone"],
                    "email": first_cg["email"],
                    "fcm_token": first_cg["fcm_token"]
                }
            }}
        )

    return jsonify({"message": "FCM device token registered successfully"}), 200

