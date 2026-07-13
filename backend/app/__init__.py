"""
TouchSpeak AI - Flask Application Factory
"""
import os
from flask import Flask
from flask_cors import CORS
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()

mongo_client = None
db = None


def create_app():
    app = Flask(__name__)
    CORS(app)

    app.config["MONGO_URI"] = os.getenv("MONGO_URI", "mongodb://localhost:27017/touchspeak")
    app.config["JWT_SECRET"] = os.getenv("JWT_SECRET", "dev-secret-change-me")
    app.config["GOOGLE_TTS_API_KEY"] = os.getenv("GOOGLE_TTS_API_KEY", "")
    app.config["GOOGLE_MAPS_API_KEY"] = os.getenv("GOOGLE_MAPS_API_KEY", "")
    app.config["FCM_SERVER_KEY"] = os.getenv("FCM_SERVER_KEY", "")

    global mongo_client, db
    mongo_client = MongoClient(app.config["MONGO_URI"])
    db = mongo_client.get_default_database()
    app.db = db

    # Register blueprints
    from app.routes.users import users_bp
    from app.routes.communication import communication_bp
    from app.routes.prediction import prediction_bp
    from app.routes.emergency import emergency_bp
    from app.routes.tts import tts_bp

    app.register_blueprint(users_bp, url_prefix="/api/users")
    app.register_blueprint(communication_bp, url_prefix="/api/communication")
    app.register_blueprint(prediction_bp, url_prefix="/api/predict")
    app.register_blueprint(emergency_bp, url_prefix="/api/emergency")
    app.register_blueprint(tts_bp, url_prefix="/api/tts")

    @app.route("/api/health")
    def health():
        return {"status": "ok", "service": "TouchSpeak AI Backend"}, 200

    @app.route("/")
    def index():
        return app.send_static_file("index.html")

    return app
