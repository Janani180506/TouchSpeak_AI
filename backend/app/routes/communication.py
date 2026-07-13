"""
Communication board endpoints: icon selection -> phrase -> logged history.
"""
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from datetime import datetime, timezone

from app.models.phrase_library import PHRASE_LIBRARY, ICON_CATEGORIES, get_phrase

communication_bp = Blueprint("communication", __name__)


@communication_bp.route("/icons", methods=["GET"])
def list_icons():
    """Returns all icon categories + their phrases in every language (for the Flutter board)."""
    return jsonify({
        "categories": ICON_CATEGORIES,
        "phrases": PHRASE_LIBRARY,
    }), 200


@communication_bp.route("/select", methods=["POST"])
def select_icon():
    """
    User taps an icon on the board.
    Body: { user_id, icon_id, language }
    Logs to communication_history and returns the phrase text (for TTS playback).
    """
    data = request.get_json(force=True)
    user_id = data.get("user_id")
    icon_id = data.get("icon_id")
    language = data.get("language", "en")

    if not user_id or not icon_id:
        return jsonify({"error": "user_id and icon_id are required"}), 400

    phrase_text = get_phrase(icon_id, language)
    if not phrase_text:
        return jsonify({"error": f"Unknown icon_id '{icon_id}'"}), 404

    history_doc = {
        "user_id": ObjectId(user_id),
        "icon_id": icon_id,
        "language": language,
        "phrase_text": phrase_text,
        "timestamp": datetime.now(timezone.utc),
    }
    current_app.db.communication_history.insert_one(history_doc)

    # Update frequently_used_phrases aggregate collection
    current_app.db.frequently_used_phrases.update_one(
        {"user_id": ObjectId(user_id), "icon_id": icon_id},
        {
            "$inc": {"use_count": 1},
            "$set": {"last_used": datetime.now(timezone.utc), "phrase_text": phrase_text},
        },
        upsert=True,
    )

    return jsonify({"icon_id": icon_id, "phrase_text": phrase_text, "language": language}), 200


@communication_bp.route("/history/<user_id>", methods=["GET"])
def get_history(user_id):
    limit = int(request.args.get("limit", 20))
    docs = list(
        current_app.db.communication_history
        .find({"user_id": ObjectId(user_id)})
        .sort("timestamp", -1)
        .limit(limit)
    )
    for d in docs:
        d["_id"] = str(d["_id"])
        d["user_id"] = str(d["user_id"])
    return jsonify(docs), 200


@communication_bp.route("/frequent/<user_id>", methods=["GET"])
def get_frequent(user_id):
    """Top most-used phrases, for the 'Frequently Used Phrases' screen."""
    limit = int(request.args.get("limit", 10))
    docs = list(
        current_app.db.frequently_used_phrases
        .find({"user_id": ObjectId(user_id)})
        .sort("use_count", -1)
        .limit(limit)
    )
    for d in docs:
        d["_id"] = str(d["_id"])
        d["user_id"] = str(d["user_id"])
    return jsonify(docs), 200


@communication_bp.route("/favorites/<user_id>", methods=["POST"])
def add_favorite(user_id):
    data = request.get_json(force=True)
    icon_id = data.get("icon_id")
    current_app.db.frequently_used_phrases.update_one(
        {"user_id": ObjectId(user_id), "icon_id": icon_id},
        {"$set": {"is_favorite": True}},
        upsert=True,
    )
    return jsonify({"message": "Marked as favorite"}), 200
