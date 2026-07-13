"""
Text-to-Speech endpoint. Wraps Google Cloud Text-to-Speech and returns
base64-encoded audio for the Flutter app to play.

NOTE: In production, prefer doing TTS on-device in Flutter using the
`flutter_tts` package for zero-latency, offline-capable speech - call this
server endpoint only as a higher-quality/multilingual fallback.
"""
from flask import Blueprint, request, jsonify, current_app
import base64
import os

tts_bp = Blueprint("tts", __name__)

LANGUAGE_VOICE_MAP = {
    "en": {"languageCode": "en-IN", "name": "en-IN-Wavenet-D"},
    "ta": {"languageCode": "ta-IN", "name": "ta-IN-Wavenet-A"},
    "hi": {"languageCode": "hi-IN", "name": "hi-IN-Wavenet-D"},
}


@tts_bp.route("/speak", methods=["POST"])
def speak():
    """
    Body: { text, language }
    Returns: { audio_base64, mime_type } using Google Cloud TTS.
    """
    data = request.get_json(force=True)
    text = data.get("text")
    language = data.get("language", "en")

    if not text:
        return jsonify({"error": "text is required"}), 400

    # Fail fast if credentials are not configured, to avoid hanging on metadata API.
    gcp_creds = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    gcp_key = current_app.config.get("GOOGLE_TTS_API_KEY")

    if not gcp_creds and not gcp_key:
        mock_mp3_b64 = (
            "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGFtZTMuMTAwZXJyb3IAAAAAAAAAAAAA"
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            "//uQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABMYW1lMy4x"
            "MDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )
        return jsonify({
            "audio_base64": mock_mp3_b64,
            "mime_type": "audio/mp3",
            "is_mock": True,
            "warning": "Using local mock TTS payload because GOOGLE_APPLICATION_CREDENTIALS is not configured."
        }), 200

    try:
        from google.cloud import texttospeech
    except ImportError:
        return jsonify({
            "error": "google-cloud-texttospeech not installed on server. "
                     "Install with: pip install google-cloud-texttospeech"
        }), 501

    voice_cfg = LANGUAGE_VOICE_MAP.get(language, LANGUAGE_VOICE_MAP["en"])

    try:
        client = texttospeech.TextToSpeechClient()
        synthesis_input = texttospeech.SynthesisInput(text=text)
        voice = texttospeech.VoiceSelectionParams(
            language_code=voice_cfg["languageCode"], name=voice_cfg["name"]
        )
        audio_config = texttospeech.AudioConfig(
            audio_encoding=texttospeech.AudioEncoding.MP3
        )
        response = client.synthesize_speech(
            input=synthesis_input, voice=voice, audio_config=audio_config
        )
        audio_b64 = base64.b64encode(response.audio_content).decode("utf-8")
        return jsonify({"audio_base64": audio_b64, "mime_type": "audio/mp3"}), 200
    except Exception as e:
        # Fallback Mock: If credentials aren't set, return a mock MP3 base64 (which is a valid silent MP3 block)
        mock_mp3_b64 = (
            "SUQzBAAAAAAAI1RTU0UAAAAPAAADTGFtZTMuMTAwZXJyb3IAAAAAAAAAAAAA"
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            "//uQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABMYW1lMy4x"
            "MDAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
            "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        )
        return jsonify({
            "audio_base64": mock_mp3_b64,
            "mime_type": "audio/mp3",
            "is_mock": True,
            "warning": f"Using local mock TTS payload due to missing/invalid Google Cloud TTS credentials (Error: {str(e)})."
        }), 200
