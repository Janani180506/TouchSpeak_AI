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
