# TouchSpeak AI
**Touch-Based Communication System for Non-Verbal Individuals**

TouchSpeak AI helps people who cannot speak or use sign language communicate
their needs, emotions, and emergencies through a simple touch-based icon
board with text-to-speech, AI phrase prediction, and multilingual (English /
Tamil / Hindi) support.

## Repository Structure

```
TouchSpeakAI/
├── backend/                 # Flask REST API
│   ├── app/
│   │   ├── routes/          # users, communication, prediction, emergency, tts
│   │   ├── models/          # phrase_library.py (icon -> phrase mapping)
│   │   ├── ml/              # phrase_predictor.py (AI recommendation engine)
│   │   ├── services/        # notification_service.py (FCM push)
│   │   └── __init__.py      # app factory
│   ├── run.py
│   ├── requirements.txt
│   └── .env.example
├── flutter_app/              # Flutter mobile app
│   └── lib/
│       ├── screens/         # communication board, emotions, frequent, emergency, profile
│       ├── widgets/         # icon_tile.dart
│       └── services/        # api_service.dart, tts_service.dart, app_state.dart
├── database/
│   ├── schema.md            # MongoDB collections, sample docs, indexes
│   └── init_db.py           # index creation + demo seed script
└── docs/
    ├── api_documentation.md
    ├── uml_diagrams.md
    ├── er_diagram.md
    ├── testing_plan.md
    └── deployment_guide.md
```

## Quick Start

### 1. Backend (Flask)
```bash
cd backend
python -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # fill in your MongoDB Atlas URI, FCM key, etc.
python run.py                     # starts on http://localhost:5000
```

### 2. Database (MongoDB Atlas)
1. Create a free cluster at https://cloud.mongodb.com
2. Copy the connection string into `backend/.env` as `MONGO_URI`
3. Create indexes and a demo user:
```bash
cd database
python init_db.py "mongodb+srv://<user>:<pass>@cluster0.mongodb.net/touchspeak"
```

### 3. Flutter App
```bash
cd flutter_app
flutter pub get
# Point lib/services/app_state.dart -> apiBaseUrl at your running backend
# (10.0.2.2 is the Android emulator's alias for your machine's localhost)
flutter run
```

### 4. Google & Firebase Setup
- **Google Cloud TTS**: enable the Text-to-Speech API in a GCP project, create a
  service account key, set `GOOGLE_APPLICATION_CREDENTIALS` env var on the backend.
- **Google Maps API**: enable Maps SDK, used for caregiver location links.
- **Firebase Cloud Messaging**: create a Firebase project, add the Flutter app
  (`flutterfire configure`), and put the server key in `backend/.env` as `FCM_SERVER_KEY`.

## How the AI Phrase Prediction Works
See `backend/app/ml/phrase_predictor.py`. It blends three signals per user:
1. **Frequency** — how often each icon has been used historically
2. **Recency** — exponential decay favoring recently used icons
3. **Sequence model** — a TF-IDF + Multinomial Naive Bayes classifier trained
   on the user's own icon-to-icon transitions, predicting "what comes next"

These are combined into a weighted score, and the top 3 icons are shown as
quick-tap suggestions above the communication board.

## Documentation
- [API Documentation](docs/api_documentation.md)
- [UML Diagrams](docs/uml_diagrams.md) (Use Case, Class, Sequence, Activity)
- [ER Diagram](docs/er_diagram.md)
- [Testing Plan](docs/testing_plan.md)
- [Deployment Guide](docs/deployment_guide.md)
- [Database Schema](database/schema.md)

## Tech Stack
| Layer | Technology |
|---|---|
| Frontend | Flutter, Dart |
| Backend | Python, Flask REST API |
| Database | MongoDB Atlas |
| AI/ML | Python, scikit-learn (TF-IDF, Naive Bayes) |
| Speech | Google Cloud Text-to-Speech, flutter_tts (on-device) |
| Location | Google Maps API, geolocator |
| Notifications | Firebase Cloud Messaging |

## License
Educational / internship project. Add a license of your choice before publishing.
