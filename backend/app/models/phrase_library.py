"""
Static icon -> phrase mapping, multi-language.
This is the core vocabulary of the communication board.
Language codes: en (English), ta (Tamil), hi (Hindi)
"""

PHRASE_LIBRARY = {
    "food": {
        "en": "I am hungry, I want food.",
        "ta": "எனக்கு பசிக்கிறது, சாப்பாடு வேண்டும்.",
        "hi": "मुझे भूख लगी है, मुझे खाना चाहिए।",
    },
    "water": {
        "en": "I am thirsty, I need water.",
        "ta": "எனக்கு தாகமாக இருக்கிறது, தண்ணீர் வேண்டும்.",
        "hi": "मुझे प्यास लगी है, मुझे पानी चाहिए।",
    },
    "medicine": {
        "en": "I need my medicine.",
        "ta": "எனக்கு மருந்து வேண்டும்.",
        "hi": "मुझे दवा चाहिए।",
    },
    "restroom": {
        "en": "I need to use the restroom.",
        "ta": "எனக்கு கழிப்பறைக்கு செல்ல வேண்டும்.",
        "hi": "मुझे शौचालय जाना है।",
    },
    "pain": {
        "en": "I am in pain, I need help.",
        "ta": "எனக்கு வலிக்கிறது, உதவி வேண்டும்.",
        "hi": "मुझे दर्द हो रहा है, मुझे मदद चाहिए।",
    },
    "help": {
        "en": "I need help right now.",
        "ta": "எனக்கு இப்போது உதவி வேண்டும்.",
        "hi": "मुझे अभी मदद चाहिए।",
    },
    "happy": {
        "en": "I am feeling happy.",
        "ta": "நான் மகிழ்ச்சியாக இருக்கிறேன்.",
        "hi": "मैं खुश हूँ।",
    },
    "sad": {
        "en": "I am feeling sad.",
        "ta": "நான் சோகமாக இருக்கிறேன்.",
        "hi": "मैं दुखी हूँ।",
    },
    "angry": {
        "en": "I am feeling angry.",
        "ta": "எனக்கு கோபமாக இருக்கிறது.",
        "hi": "मुझे गुस्सा आ रहा है।",
    },
    "scared": {
        "en": "I am feeling scared.",
        "ta": "எனக்கு பயமாக இருக்கிறது.",
        "hi": "मुझे डर लग रहा है।",
    },
    "tired": {
        "en": "I am feeling tired.",
        "ta": "நான் சோர்வாக இருக்கிறேன்.",
        "hi": "मैं थका हुआ हूँ।",
    },
    "emergency": {
        "en": "This is an emergency, I need immediate help.",
        "ta": "இது அவசரநிலை, உடனடி உதவி தேவை.",
        "hi": "यह एक आपातकाल है, मुझे तुरंत मदद चाहिए।",
    },
}

# Categories used by the Flutter communication board UI
ICON_CATEGORIES = {
    "needs": ["food", "water", "medicine", "restroom", "pain", "help"],
    "emotions": ["happy", "sad", "angry", "scared", "tired"],
    "emergency": ["emergency"],
}


def get_phrase(icon_id: str, lang: str = "en") -> str:
    # First check if db is available in current_app to query dynamic cards
    try:
        from flask import current_app
        from bson import ObjectId
        if current_app and hasattr(current_app, "db") and current_app.db is not None:
            query = {}
            if ObjectId.is_valid(icon_id):
                query["_id"] = ObjectId(icon_id)
            else:
                query["title"] = icon_id

            card = current_app.db.communication_cards.find_one(query)
            if card:
                translations = card.get("translations", {})
                if translations and lang in translations:
                    return translations[lang]

                # Fallback fields directly on the card
                en_val = card.get("en_translation") or card.get("phrase") or card.get("title")
                if lang == "en":
                    return en_val or ""
                elif lang == "ta":
                    return card.get("ta_translation") or en_val or ""
                elif lang == "hi":
                    return card.get("hi_translation") or en_val or ""
                return en_val or ""
    except Exception:
        pass

    entry = PHRASE_LIBRARY.get(icon_id)
    if not entry:
        return ""
    return entry.get(lang, entry.get("en", ""))

