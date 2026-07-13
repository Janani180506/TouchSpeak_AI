"""
AI phrase prediction endpoint.
"""
from flask import Blueprint, jsonify, current_app
from bson import ObjectId

from app.ml.phrase_predictor import PhrasePredictor, cold_start_suggestions
from app.models.phrase_library import get_phrase

prediction_bp = Blueprint("prediction", __name__)


@prediction_bp.route("/<user_id>", methods=["GET"])
def predict(user_id):
    """
    Returns the top-3 predicted next icons/phrases for this user based on
    their communication history (frequency + recency + Naive Bayes sequence model).
    """
    history = list(
        current_app.db.communication_history
        .find({"user_id": ObjectId(user_id)})
        .sort("timestamp", 1)  # oldest -> newest, required by the predictor
    )

    if not history:
        suggestions = cold_start_suggestions()
    else:
        predictor = PhrasePredictor(history)
        suggestions = predictor.predict_top_n(n=3)
        if not suggestions:
            suggestions = cold_start_suggestions()

    # Attach display text (English default; frontend can re-resolve per language)
    for s in suggestions:
        s["phrase_text"] = get_phrase(s["icon_id"], "en")

    return jsonify({"user_id": user_id, "predictions": suggestions}), 200
