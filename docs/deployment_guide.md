# TouchSpeak AI — Deployment Guide

## 1. Database — MongoDB Atlas
1. Create a free/shared cluster at https://cloud.mongodb.com.
2. Add your deployment server's IP (or `0.0.0.0/0` for early testing only) to Network Access.
3. Create a database user with read/write access to the `touchspeak` database.
4. Copy the SRV connection string → set as `MONGO_URI` in production env vars.
5. Run `python database/init_db.py "<MONGO_URI>"` once to create indexes.

## 2. Backend — Flask API
Recommended: containerize with Docker, deploy to Render / Railway / AWS Elastic
Beanstalk / Google Cloud Run.

**Dockerfile** (create at `backend/Dockerfile`):
```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "run:app"]
```

Build & run locally:
```bash
docker build -t touchspeak-backend ./backend
docker run -p 5000:5000 --env-file backend/.env touchspeak-backend
```

**Cloud Run deployment (example)**:
```bash
gcloud run deploy touchspeak-backend \
  --source ./backend \
  --region asia-south1 \
  --allow-unauthenticated \
  --set-env-vars MONGO_URI="...",FCM_SERVER_KEY="..."
```

Set environment variables (`MONGO_URI`, `JWT_SECRET`, `GOOGLE_TTS_API_KEY`,
`GOOGLE_MAPS_API_KEY`, `FCM_SERVER_KEY`) in your host's secret manager — never
commit `.env` to version control.

## 3. Google Cloud Setup
- **Text-to-Speech API**: enable in GCP Console → create a service account →
  download JSON key → set `GOOGLE_APPLICATION_CREDENTIALS` to its path on the server.
- **Maps API**: enable "Maps SDK for Android/iOS" + "Geocoding API"; restrict
  the API key to your app's package name/bundle ID and server IP.

## 4. Firebase Setup (Push Notifications)
1. Create a Firebase project → add Android & iOS apps.
2. Run `flutterfire configure` inside `flutter_app/` to generate `firebase_options.dart`.
3. In Firebase Console → Project Settings → Cloud Messaging, copy the **Server
   Key** (legacy) or set up HTTP v1 with a service account — set as `FCM_SERVER_KEY`.
4. On first app launch, request notification permission and register the
   caregiver's device FCM token via `PUT /api/users/<id>` (`caregiver.fcm_token`).

## 5. Flutter App — Build & Release
```bash
cd flutter_app
flutter pub get

# Android release build
flutter build apk --release
# or app bundle for Play Store
flutter build appbundle --release

# iOS release build (on macOS with Xcode)
flutter build ios --release
```
Before release:
- Update `apiBaseUrl` in `lib/services/app_state.dart` to your production HTTPS URL.
- Add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.
- Set app icons/splash screen, and request Android permissions in
  `AndroidManifest.xml`: `INTERNET`, `ACCESS_FINE_LOCATION`, `POST_NOTIFICATIONS`.

## 6. CI/CD (suggested)
- GitHub Actions: run `pytest` on backend + `flutter test` on push.
- On merge to `main`: auto-deploy backend container to Cloud Run/Render;
  build & upload Flutter artifacts to Play Console/TestFlight via Fastlane.

## 7. Monitoring
- Add basic logging (`app.logger`) and connect to a log sink (Cloud Logging / Sentry).
- Track SOS delivery failures (`caregiver_notified: false`) — alert on spikes,
  since this is the safety-critical path of the app.
