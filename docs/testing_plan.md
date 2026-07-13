# TouchSpeak AI — Testing Plan

## 1. Backend Unit Tests (pytest)
Location: `backend/tests/` (create this folder)

| Module | Test Cases |
|---|---|
| `phrase_library.py` | `get_phrase()` returns correct text per icon/language; unknown icon returns empty string |
| `phrase_predictor.py` | frequency_scores sums to ~1.0; recency_scores favors latest events; sequence model degrades gracefully with <4 history events; predict_top_n returns ≤ n results |
| `routes/users.py` | create user validates required fields; 404 on missing user id |
| `routes/communication.py` | select_icon logs to history + upserts frequent phrases; unknown icon_id → 404 |
| `routes/emergency.py` | SOS with missing lat/lng → 400; SOS with valid data creates log and returns notified status |

Example test (using `mongomock` to avoid a real DB):
```python
def test_select_icon_logs_history(client, seeded_user):
    res = client.post("/api/communication/select", json={
        "user_id": seeded_user, "icon_id": "food", "language": "en"
    })
    assert res.status_code == 200
    assert "hungry" in res.get_json()["phrase_text"]
```

Run with: `pytest backend/tests -v`

## 2. AI Model Validation
- **Cold start**: new user with 0 history → returns default suggestions, no crash.
- **Small history (1–3 events)**: sequence model should skip gracefully (Naive
  Bayes needs ≥2 classes), frequency/recency signals still work.
- **Repeated pattern**: feed a synthetic repeating sequence (e.g. food→water→food→water)
  and assert the predictor's top prediction matches the expected next icon.
- **Accuracy tracking**: log actual-vs-predicted icon match rate over time in
  a `prediction_accuracy` collection to monitor real-world model quality.

## 3. API / Integration Tests
- Use Postman or `pytest` + `requests` against a running instance.
- Cover full user journey: create user → select icons ×5 → get predictions →
  trigger SOS → fetch history/logs.
- Test error handling: malformed JSON, missing fields, invalid ObjectId strings.

## 4. Flutter Widget & Integration Tests
- `flutter test`: widget tests for `IconTile` (renders label + icon, triggers
  `onTap`), `CommunicationBoardScreen` (renders 6 need icons).
- `flutter drive` / integration_test: full flow — tap icon → verify TTS called
  → verify API call fired → verify prediction strip updates.
- Manual device testing checklist:
  - [ ] TTS works in English, Tamil, Hindi
  - [ ] SOS button reachable within 1 tap from any screen
  - [ ] App works offline (icon taps still speak locally even without network)
  - [ ] Large touch targets usable by children / motor-impaired users

## 5. Accessibility Testing
- Screen contrast ratio ≥ 4.5:1 (WCAG AA) on all icon tiles.
- Test with TalkBack/VoiceOver disabled (app is icon-driven, not screen-reader dependent).
- Test with a non-literate user persona: can they operate the app using only
  icons/colors, with zero text comprehension?

## 6. Load & Reliability Testing
- Simulate 100 concurrent `/api/predict/<user_id>` calls with `locust` — ensure
  Naive Bayes retraining-on-request stays under ~200ms per user (small per-user data).
- MongoDB Atlas: verify indexes are used via `explain()` on `communication_history` queries.

## 7. Security Testing
- Verify all endpoints reject malformed ObjectIds instead of crashing (500).
- Verify `.env` secrets are never committed (check `.gitignore`).
- Verify FCM server key / Google API keys are server-side only, never shipped
  in the Flutter app bundle.
