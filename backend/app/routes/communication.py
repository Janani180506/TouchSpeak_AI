"""
Caregiver & Communication Board Endpoints: category/card management, image uploads, favorites, and board data.
"""
import os
import time
from datetime import datetime, timezone
from flask import Blueprint, request, jsonify, current_app
from bson import ObjectId
from werkzeug.utils import secure_filename

from app.models.phrase_library import PHRASE_LIBRARY, ICON_CATEGORIES, get_phrase

communication_bp = Blueprint("communication", __name__)


def seed_database_if_empty(db):
    """Seed the database with default categories and cards if empty."""
    if db.categories.count_documents({}) > 0:
        return

    # Seed categories
    categories_to_seed = [
        {"name": "Needs", "icon": "restaurant", "display_order": 1},
        {"name": "Emotions", "icon": "sentiment_very_satisfied", "display_order": 2},
        {"name": "Emergency", "icon": "emergency", "display_order": 3},
    ]

    category_ids = {}
    for cat in categories_to_seed:
        inserted = db.categories.insert_one(cat)
        category_ids[cat["name"].lower()] = inserted.inserted_id

    # Seed communication cards
    cards_to_seed = [
        # Needs
        {
            "category_id": category_ids["needs"],
            "title": "Food",
            "phrase": "I am hungry, I want food.",
            "translations": {
                "en": "I am hungry, I want food.",
                "ta": "எனக்கு பசிக்கிறது, சாப்பாடு வேண்டும்.",
                "hi": "मुझे भूख लगी है, मुझे खाना चाहिए।"
            },
            "icon": "restaurant",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 1
        },
        {
            "category_id": category_ids["needs"],
            "title": "Water",
            "phrase": "I need water.",
            "translations": {
                "en": "I am thirsty, I need water.",
                "ta": "எனக்கு தாகமாக இருக்கிறது, தண்ணீர் வேண்டும்.",
                "hi": "मुझे प्यास लगी है, मुझे पानी चाहिए।"
            },
            "icon": "water_drop",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 2
        },
        {
            "category_id": category_ids["needs"],
            "title": "Medicine",
            "phrase": "I need my medicine.",
            "translations": {
                "en": "I need my medicine.",
                "ta": "எனக்கு மருந்து வேண்டும்.",
                "hi": "मुझे दवा चाहिए।"
            },
            "icon": "medication",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 3
        },
        {
            "category_id": category_ids["needs"],
            "title": "Restroom",
            "phrase": "I need to use the restroom.",
            "translations": {
                "en": "I need to use the restroom.",
                "ta": "எனக்கு கழிப்பறைக்கு செல்ல வேண்டும்.",
                "hi": "मुझे शौचालय जाना है।"
            },
            "icon": "wc",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 4
        },
        {
            "category_id": category_ids["needs"],
            "title": "Pain",
            "phrase": "I am in pain, I need help.",
            "translations": {
                "en": "I am in pain, I need help.",
                "ta": "எனக்கு வலிக்கிறது, உதவி வேண்டும்.",
                "hi": "मुझे दर्द हो रहा है, मुझे मदद चाहिए।"
            },
            "icon": "healing",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 5
        },
        {
            "category_id": category_ids["needs"],
            "title": "Help",
            "phrase": "I need help right now.",
            "translations": {
                "en": "I need help right now.",
                "ta": "எனக்கு இப்போது உதவி வேண்டும்.",
                "hi": "मुझे अभी मदद चाहिए।"
            },
            "icon": "pan_tool",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 6
        },
        # Emotions
        {
            "category_id": category_ids["emotions"],
            "title": "Happy",
            "phrase": "I am feeling happy.",
            "translations": {
                "en": "I am feeling happy.",
                "ta": "நான் மகிழ்ச்சியாக இருக்கிறேன்.",
                "hi": "मैं खुश हूँ।"
            },
            "icon": "sentiment_very_satisfied",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 1
        },
        {
            "category_id": category_ids["emotions"],
            "title": "Sad",
            "phrase": "I am feeling sad.",
            "translations": {
                "en": "I am feeling sad.",
                "ta": "நான் சோகமாக இருக்கிறேன்.",
                "hi": "நான் சோகமாக இருக்கிறேன்."  # Fallback
            },
            "icon": "sentiment_dissatisfied",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 2
        },
        {
            "category_id": category_ids["emotions"],
            "title": "Angry",
            "phrase": "I am feeling angry.",
            "translations": {
                "en": "I am feeling angry.",
                "ta": "எனக்கு கோபமாக இருக்கிறது.",
                "hi": "मुझे गुस्सा आ रहा है।"
            },
            "icon": "sentiment_very_dissatisfied",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 3
        },
        {
            "category_id": category_ids["emotions"],
            "title": "Scared",
            "phrase": "I am feeling scared.",
            "translations": {
                "en": "I am feeling scared.",
                "ta": "எனக்கு பயமாக இருக்கிறது.",
                "hi": "मुझे डर लग रहा है।"
            },
            "icon": "sentiment_neutral",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 4
        },
        {
            "category_id": category_ids["emotions"],
            "title": "Tired",
            "phrase": "I am feeling tired.",
            "translations": {
                "en": "I am feeling tired.",
                "ta": "நான் சோர்வாக இருக்கிறேன்.",
                "hi": "मैं थका हुआ हूँ।"
            },
            "icon": "bedtime",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 5
        },
        # Emergency
        {
            "category_id": category_ids["emergency"],
            "title": "Emergency",
            "phrase": "This is an emergency, I need immediate help.",
            "translations": {
                "en": "This is an emergency, I need immediate help.",
                "ta": "இது அவசரநிலை, உடனடி உதவி தேவை.",
                "hi": "यह एक आपातकाल है, मुझे तुरंत मदद चाहिए।"
            },
            "icon": "emergency",
            "image_path": "",
            "voice_recording_path": "",
            "display_order": 1
        },
    ]

    # For 'Sad' Hindi translation
    for card in cards_to_seed:
        if card["title"] == "Sad":
            card["translations"]["hi"] = "मैं दुखी हूँ।"

    db.communication_cards.insert_many(cards_to_seed)


@communication_bp.route("/icons", methods=["GET"])
def list_icons():
    """Returns all icon categories + their phrases in every language (for the Flutter board)."""
    seed_database_if_empty(current_app.db)

    # Load from DB
    cats = list(current_app.db.categories.find().sort("display_order", 1))
    cards = list(current_app.db.communication_cards.find().sort("display_order", 1))

    categories_dict = {}
    phrases_dict = {}

    # Backward compatibility mappings for test suite and old verify scripts
    # (e.g. they look for static icon names like 'food', 'water' as keys in categories/phrases)
    static_to_dynamic_ids = {}

    for cat in cats:
        cat_key = cat["name"].lower()
        categories_dict[cat_key] = []

        cat_cards = [c for c in cards if c["category_id"] == cat["_id"]]
        for card in cat_cards:
            card_id_str = str(card["_id"])
            categories_dict[cat_key].append(card_id_str)

            translations = card.get("translations", {
                "en": card.get("phrase", ""),
                "ta": card.get("ta_translation", ""),
                "hi": card.get("hi_translation", "")
            })
            phrases_dict[card_id_str] = translations

            # Store mapping to keep support for static names 'food', 'water', etc.
            title_lower = card["title"].lower()
            static_to_dynamic_ids[title_lower] = card_id_str

    # Inject static keys matching seeded ones, ensuring tests/verification still passes
    for key, value in PHRASE_LIBRARY.items():
        phrases_dict[key] = value
        # Make sure they are in categories too
        for cat_name, icon_list in ICON_CATEGORIES.items():
            if key in icon_list and cat_name in categories_dict:
                if key not in categories_dict[cat_name]:
                    # Let's map it or insert it
                    categories_dict[cat_name].append(key)

    return jsonify({
        "categories": categories_dict,
        "phrases": phrases_dict,
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


@communication_bp.route("/favorites/<user_id>", methods=["GET"])
def get_favorites(user_id):
    """Get all favorite communication cards of a user."""
    favs = list(current_app.db.favorites.find({"user_id": ObjectId(user_id)}))
    card_ids = [f["card_id"] for f in favs]
    cards = list(current_app.db.communication_cards.find({"_id": {"$in": card_ids}}))
    for c in cards:
        c["_id"] = str(c["_id"])
        c["category_id"] = str(c["category_id"])
    return jsonify(cards), 200


@communication_bp.route("/favorites/<user_id>", methods=["POST"])
def toggle_favorite(user_id):
    """Toggle a card as a favorite or set explicitly."""
    data = request.get_json(force=True)
    card_id = data.get("card_id")
    is_fav = data.get("is_favorite", True)

    if not card_id:
        return jsonify({"error": "card_id is required"}), 400

    # Ensure valid ObjectId
    try:
        c_id = ObjectId(card_id)
        u_id = ObjectId(user_id)
    except Exception:
        # Fallback to string if card is static / not an ObjectId (support old tests)
        c_id = card_id
        try:
            u_id = ObjectId(user_id)
        except Exception:
            return jsonify({"error": "Invalid user_id or card_id"}), 400

    if is_fav:
        # Insert if not exists
        current_app.db.favorites.update_one(
            {"user_id": u_id, "card_id": c_id},
            {"$set": {"created_at": datetime.now(timezone.utc)}},
            upsert=True
        )
        current_app.db.frequently_used_phrases.update_one(
            {"user_id": u_id, "icon_id": card_id},
            {"$set": {"is_favorite": True}},
            upsert=True
        )
        return jsonify({"message": "Marked as favorite"}), 200
    else:
        # Delete
        current_app.db.favorites.delete_one({"user_id": u_id, "card_id": c_id})
        current_app.db.frequently_used_phrases.update_one(
            {"user_id": u_id, "icon_id": card_id},
            {"$set": {"is_favorite": False}}
        )
        return jsonify({"message": "Removed from favorites"}), 200


# =====================================================================
# CAREGIVER DIRECT REST APIS
# =====================================================================

@communication_bp.route("/categories", methods=["GET"])
def get_categories():
    """Retrieve all categories."""
    seed_database_if_empty(current_app.db)
    cats = list(current_app.db.categories.find().sort("display_order", 1))
    for c in cats:
        c["_id"] = str(c["_id"])
    return jsonify(cats), 200


@communication_bp.route("/categories", methods=["POST"])
def create_category():
    """Create a new category. Validates duplicate category names."""
    data = request.get_json(force=True)
    name = data.get("name", "").strip()
    icon = data.get("icon", "grid_view").strip()
    display_order = data.get("display_order")

    if not name:
        return jsonify({"error": "Category name is required and cannot be empty"}), 400

    # Ensure display order is set
    if display_order is None:
        max_cat = current_app.db.categories.find_one(sort=[("display_order", -1)])
        display_order = (max_cat["display_order"] + 1) if max_cat else 1
    else:
        try:
            display_order = int(display_order)
        except ValueError:
            return jsonify({"error": "display_order must be an integer"}), 400

    # Validation: Case insensitive duplicate check
    existing = current_app.db.categories.find_one({"name": {"$regex": f"^{name}$", "$options": "i"}})
    if existing:
        return jsonify({"error": f"A category with name '{name}' already exists"}), 400

    cat_doc = {
        "name": name,
        "icon": icon,
        "display_order": display_order
    }
    current_app.db.categories.insert_one(cat_doc)
    cat_doc["_id"] = str(cat_doc["_id"])
    return jsonify(cat_doc), 201


@communication_bp.route("/categories/<id>", methods=["PUT"])
def update_category(id):
    """Update a category."""
    if not ObjectId.is_valid(id):
        return jsonify({"error": "Invalid Category ID"}), 400

    data = request.get_json(force=True)
    name = data.get("name", "").strip()
    icon = data.get("icon")
    display_order = data.get("display_order")

    update_fields = {}
    if name:
        # Prevent duplicates
        existing = current_app.db.categories.find_one({
            "name": {"$regex": f"^{name}$", "$options": "i"},
            "_id": {"$ne": ObjectId(id)}
        })
        if existing:
            return jsonify({"error": f"A category with name '{name}' already exists"}), 400
        update_fields["name"] = name

    if icon is not None:
        update_fields["icon"] = icon.strip()

    if display_order is not None:
        try:
            update_fields["display_order"] = int(display_order)
        except ValueError:
            return jsonify({"error": "display_order must be an integer"}), 400

    if not update_fields:
        return jsonify({"message": "Nothing to update"}), 200

    res = current_app.db.categories.update_one({"_id": ObjectId(id)}, {"$set": update_fields})
    if res.matched_count == 0:
        return jsonify({"error": "Category not found"}), 404

    updated_cat = current_app.db.categories.find_one({"_id": ObjectId(id)})
    updated_cat["_id"] = str(updated_cat["_id"])
    return jsonify(updated_cat), 200


@communication_bp.route("/categories/<id>", methods=["DELETE"])
def delete_category(id):
    """Delete a category and its associated cards."""
    if not ObjectId.is_valid(id):
        return jsonify({"error": "Invalid Category ID"}), 400

    res = current_app.db.categories.delete_one({"_id": ObjectId(id)})
    if res.deleted_count == 0:
        return jsonify({"error": "Category not found"}), 404

    # Delete all communication cards under this category as well
    current_app.db.communication_cards.delete_many({"category_id": ObjectId(id)})

    return jsonify({"message": "Category and all associated cards deleted successfully"}), 200


@communication_bp.route("/cards", methods=["GET"])
def get_cards():
    """Retrieve cards, with optional category_id filtering and search query."""
    seed_database_if_empty(current_app.db)
    category_id = request.args.get("category_id")
    search_q = request.args.get("q", "").strip()

    query = {}
    if category_id:
        if not ObjectId.is_valid(category_id):
            return jsonify({"error": "Invalid Category ID"}), 400
        query["category_id"] = ObjectId(category_id)

    if search_q:
        # Search title, phrase, translations
        query["$or"] = [
            {"title": {"$regex": search_q, "$options": "i"}},
            {"phrase": {"$regex": search_q, "$options": "i"}},
            {"translations.en": {"$regex": search_q, "$options": "i"}},
            {"translations.ta": {"$regex": search_q, "$options": "i"}},
            {"translations.hi": {"$regex": search_q, "$options": "i"}},
        ]

    cards = list(current_app.db.communication_cards.find(query).sort("display_order", 1))
    for c in cards:
        c["_id"] = str(c["_id"])
        c["category_id"] = str(c["category_id"])
    return jsonify(cards), 200


@communication_bp.route("/cards", methods=["POST"])
def create_card():
    """Create a new communication card."""
    data = request.get_json(force=True)
    title = data.get("title", "").strip()
    phrase = data.get("phrase", "").strip()
    category_id = data.get("category_id")
    icon = data.get("icon", "grid_view").strip()
    image_path = data.get("image_path", "").strip()
    voice_recording_path = data.get("voice_recording_path", "").strip()
    display_order = data.get("display_order")

    # Validations
    if not title:
        return jsonify({"error": "Card title is required"}), 400
    if not phrase:
        return jsonify({"error": "Card phrase is required"}), 400
    if not category_id:
        return jsonify({"error": "Category ID is required"}), 400
    if not ObjectId.is_valid(category_id):
        return jsonify({"error": "Invalid Category ID"}), 400

    # Ensure Category exists
    if not current_app.db.categories.find_one({"_id": ObjectId(category_id)}):
        return jsonify({"error": "Category not found"}), 404

    # Determine display order if not specified
    if display_order is None:
        max_card = current_app.db.communication_cards.find_one(
            {"category_id": ObjectId(category_id)},
            sort=[("display_order", -1)]
        )
        display_order = (max_card["display_order"] + 1) if max_card else 1
    else:
        try:
            display_order = int(display_order)
        except ValueError:
            return jsonify({"error": "display_order must be an integer"}), 400

    # Translations
    translations = data.get("translations", {})
    # Populate default translations if missing
    if "en" not in translations or not translations["en"]:
        translations["en"] = data.get("en_translation", phrase)
    if "ta" not in translations or not translations["ta"]:
        translations["ta"] = data.get("ta_translation", "")
    if "hi" not in translations or not translations["hi"]:
        translations["hi"] = data.get("hi_translation", "")

    card_doc = {
        "category_id": ObjectId(category_id),
        "title": title,
        "phrase": phrase,
        "translations": translations,
        "icon": icon,
        "image_path": image_path,
        "voice_recording_path": voice_recording_path,
        "display_order": display_order
    }

    current_app.db.communication_cards.insert_one(card_doc)
    card_doc["_id"] = str(card_doc["_id"])
    card_doc["category_id"] = str(card_doc["category_id"])

    return jsonify(card_doc), 201


@communication_bp.route("/cards/<id>", methods=["PUT"])
def update_card(id):
    """Update a card."""
    if not ObjectId.is_valid(id):
        return jsonify({"error": "Invalid Card ID"}), 400

    data = request.get_json(force=True)
    title = data.get("title", "").strip()
    phrase = data.get("phrase", "").strip()
    category_id = data.get("category_id")
    icon = data.get("icon")
    image_path = data.get("image_path")
    voice_recording_path = data.get("voice_recording_path")
    display_order = data.get("display_order")
    translations = data.get("translations")

    update_fields = {}
    if title:
        update_fields["title"] = title
    if phrase:
        update_fields["phrase"] = phrase
    if category_id:
        if not ObjectId.is_valid(category_id):
            return jsonify({"error": "Invalid Category ID"}), 400
        if not current_app.db.categories.find_one({"_id": ObjectId(category_id)}):
            return jsonify({"error": "Category not found"}), 404
        update_fields["category_id"] = ObjectId(category_id)

    if icon is not None:
        update_fields["icon"] = icon.strip()
    if image_path is not None:
        update_fields["image_path"] = image_path.strip()
    if voice_recording_path is not None:
        update_fields["voice_recording_path"] = voice_recording_path.strip()

    if display_order is not None:
        try:
            update_fields["display_order"] = int(display_order)
        except ValueError:
            return jsonify({"error": "display_order must be an integer"}), 400

    if translations:
        update_fields["translations"] = translations
    elif title or phrase:
        # Update English translation if phrase/title modified
        card = current_app.db.communication_cards.find_one({"_id": ObjectId(id)})
        if card:
            t = card.get("translations", {})
            if phrase:
                t["en"] = phrase
            update_fields["translations"] = t

    if not update_fields:
        return jsonify({"message": "Nothing to update"}), 200

    res = current_app.db.communication_cards.update_one({"_id": ObjectId(id)}, {"$set": update_fields})
    if res.matched_count == 0:
        return jsonify({"error": "Card not found"}), 404

    updated_card = current_app.db.communication_cards.find_one({"_id": ObjectId(id)})
    updated_card["_id"] = str(updated_card["_id"])
    updated_card["category_id"] = str(updated_card["category_id"])
    return jsonify(updated_card), 200


@communication_bp.route("/cards/<id>", methods=["DELETE"])
def delete_card(id):
    """Delete a card."""
    if not ObjectId.is_valid(id):
        return jsonify({"error": "Invalid Card ID"}), 400

    res = current_app.db.communication_cards.delete_one({"_id": ObjectId(id)})
    if res.deleted_count == 0:
        return jsonify({"error": "Card not found"}), 404

    # Remove from Favorites
    current_app.db.favorites.delete_many({"card_id": ObjectId(id)})

    return jsonify({"message": "Card deleted successfully"}), 200


@communication_bp.route("/cards/reorder", methods=["POST"])
def reorder_cards():
    """Bulk update card display orders for drag-and-drop support."""
    data = request.get_json(force=True)
    card_ids = data.get("card_ids")

    if not card_ids or not isinstance(card_ids, list):
        return jsonify({"error": "card_ids list is required"}), 400

    for idx, cid in enumerate(card_ids):
        if ObjectId.is_valid(cid):
            current_app.db.communication_cards.update_one(
                {"_id": ObjectId(cid)},
                {"$set": {"display_order": idx + 1}}
            )

    return jsonify({"message": "Cards reordered successfully"}), 200


@communication_bp.route("/upload-image", methods=["POST"])
def upload_image():
    """Upload custom images and save to local disk."""
    if "image" not in request.files:
        return jsonify({"error": "No image catalog part in request"}), 400

    file = request.files["image"]
    if file.filename == "":
        return jsonify({"error": "No image file selected"}), 400

    # Image extension validation
    allowed_extensions = {"png", "jpg", "jpeg", "webp", "gif"}
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in allowed_extensions:
        return jsonify({"error": "Invalid file type. Allowed formats: PNG, JPG, JPEG, WEBP, GIF"}), 400

    filename = f"{int(time.time())}_{secure_filename(file.filename)}"
    upload_dir = os.path.join(current_app.root_path, "static", "uploads")
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)

    file.save(filepath)

    relative_url = f"/static/uploads/{filename}"

    # Log to Images collection
    image_doc = {
        "filename": filename,
        "filepath": relative_url,
        "uploaded_at": datetime.now(timezone.utc)
    }
    current_app.db.images.insert_one(image_doc)
    image_doc["_id"] = str(image_doc["_id"])
    image_doc["url"] = relative_url

    return jsonify(image_doc), 200
