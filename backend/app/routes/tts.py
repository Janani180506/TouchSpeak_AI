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
    Returns: { audio_base64, mime_type } using Google Cloud TTS or gTTS fallback.
    """
    data = request.get_json(force=True)
    text = data.get("text")
    language = data.get("language") # Remove default hardcoded "en"

    if not text:
        print("[TTS Backend Error] text parameter is required")
        return jsonify({"error": "text is required"}), 400

    if not language:
        print("[TTS Backend Error] language parameter is required")
        return jsonify({"error": "language is required"}), 400

    print(f"[TTS Backend] Selected language: {language}")

    # Standardize language code for gTTS (use e.g. "ta", "hi", "en")
    # For Google Cloud, use the regional voice mapping
    voice_cfg = LANGUAGE_VOICE_MAP.get(language)
    if not voice_cfg:
        print(f"[TTS Backend Error] Unsupported language value: {language}")
        return jsonify({"error": f"Unsupported language '{language}'"}), 400

    print(f"[TTS Backend] Selected voice: {voice_cfg['name']}")

    # Fail fast if credentials are not configured, to avoid hanging on metadata API.
    gcp_creds = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
    gcp_key = current_app.config.get("GOOGLE_TTS_API_KEY")

    if not gcp_creds and not gcp_key:
        print("[TTS Backend Check] Google Cloud credentials not configured. Falling back to local gTTS synthesis.")
        try:
            from gtts import gTTS
            import io
            
            # Synthesize real speech bytes using gTTS
            # lang code is the two-letter language code (e.g. "ta" for Tamil, "hi" for Hindi, "en" for English)
            tts = gTTS(text=text, lang=language)
            fp = io.BytesIO()
            tts.write_to_fp(fp)
            fp.seek(0)
            audio_b64 = base64.b64encode(fp.read()).decode("utf-8")
            
            print(f"[TTS Backend] Successfully synthesized real audio via gTTS for lang: {language}")
            return jsonify({
                "audio_base64": audio_b64,
                "mime_type": "audio/mp3",
                "is_gtts": True
            }), 200
        except Exception as e:
            err_msg = f"gTTS offline synthesis failed: {e}"
            print(f"[TTS Backend Error] {err_msg}")
            # Fallback Mock: If gTTS fails, return a mock MP3 base64
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
                "warning": f"Using local mock TTS payload due to missing Google Cloud credentials and gTTS library error (Error: {str(e)})."
            }), 200

    try:
        from google.cloud import texttospeech
    except ImportError as e:
        print(f"[TTS Backend Error] google-cloud-texttospeech library import failed: {e}")
        return jsonify({
            "error": "google-cloud-texttospeech not installed on server. "
                     "Install with: pip install google-cloud-texttospeech"
        }), 501

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
        print(f"[TTS Backend] Successfully synthesized audio via Google Cloud TTS for voice {voice_cfg['name']}")
        return jsonify({"audio_b64": audio_b64, "mime_type": "audio/mp3"}), 200
    except Exception as e:
        err_msg = f"Google Cloud TTS synthesis failed: {e}"
        print(f"[TTS Backend Error] {err_msg}")
        
        # Fallback to gTTS if Google Cloud TTS fails
        print("[TTS Backend Check] Falling back to gTTS synthesis after Google Cloud error.")
        try:
            from gtts import gTTS
            import io
            tts = gTTS(text=text, lang=language)
            fp = io.BytesIO()
            tts.write_to_fp(fp)
            fp.seek(0)
            audio_b64 = base64.b64encode(fp.read()).decode("utf-8")
            print(f"[TTS Backend] Successfully synthesized real audio via gTTS for lang: {language}")
            return jsonify({
                "audio_base64": audio_b64,
                "mime_type": "audio/mp3",
                "is_gtts": True
            }), 200
        except Exception as fallback_err:
            fallback_err_msg = f"gTTS fallback synthesis failed: {fallback_err}"
            print(f"[TTS Backend Error] {fallback_err_msg}")
            
            # Final Fallback Mock
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
                "warning": f"Using local mock TTS payload due to missing/invalid Google Cloud TTS credentials (Error: {str(e)}) and failed gTTS (Error: {str(fallback_err)})."
            }), 200
