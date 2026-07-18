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
    app.config["SMTP_SERVER"] = os.getenv("SMTP_SERVER", "")
    app.config["SMTP_PORT"] = os.getenv("SMTP_PORT", "587")
    app.config["SMTP_USERNAME"] = os.getenv("SMTP_USERNAME", "")
    app.config["SMTP_PASSWORD"] = os.getenv("SMTP_PASSWORD", "")
    app.config["SENDER_EMAIL"] = os.getenv("SENDER_EMAIL", "sos@touchspeak.ai")

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

    @app.route("/board_controller.js")
    def serve_board_controller():
        return app.send_static_file("board_controller.js")

    @app.route("/firebase-messaging-sw.js")
    def serve_sw():
        import os
        from dotenv import load_dotenv
        load_dotenv(override=True)
        config_js = f"""
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

const firebaseConfig = {{
    apiKey: "{os.getenv("FIREBASE_API_KEY", "")}",
    authDomain: "{os.getenv("FIREBASE_AUTH_DOMAIN", "")}",
    projectId: "{os.getenv("FIREBASE_PROJECT_ID", "touchspeakai")}",
    storageBucket: "{os.getenv("FIREBASE_STORAGE_BUCKET", "")}",
    messagingSenderId: "{os.getenv("FIREBASE_MESSAGING_SENDER_ID", "116629924465")}",
    appId: "{os.getenv("FIREBASE_APP_ID", "")}",
    measurementId: "{os.getenv("FIREBASE_MEASUREMENT_ID", "")}"
}};

firebase.initializeApp(firebaseConfig);
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {{
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {{
        body: payload.notification.body,
        data: payload.data,
        icon: '/favicon.ico'
    }};

    self.registration.showNotification(notificationTitle, notificationOptions);
}});
"""
        return app.response_class(config_js, mimetype='application/javascript')

    return app
