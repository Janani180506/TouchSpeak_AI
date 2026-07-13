# TouchSpeak AI — API Documentation

Base URL (local): `http://localhost:5000/api`

All request/response bodies are JSON. All `_id` fields are MongoDB ObjectId strings.

---
## Health
`GET /health` → `{ "status": "ok", "service": "TouchSpeak AI Backend" }`

---
## Users
| Method | Endpoint | Description |
|---|---|---|
| POST | `/users` | Create a user profile |
| GET | `/users/<id>` | Get a user profile |
| PUT | `/users/<id>` | Update a user profile |
| GET | `/users/<id>/preferences` | Get user preferences |
| PUT | `/users/<id>/preferences` | Update user preferences |

**POST /users** — Body:
```json
{
  "name": "Arun Kumar",
  "age": 9,
  "preferred_language": "ta",
  "caregiver": { "name": "Meena", "phone": "+91...", "email": "m@x.com" },
  "emergency_contacts": []
}
```

---
## Communication
| Method | Endpoint | Description |
|---|---|---|
| GET | `/communication/icons` | All icon categories + phrases (all languages) |
| POST | `/communication/select` | Log an icon tap, get phrase text back |
| GET | `/communication/history/<user_id>?limit=20` | Recent communication history |
| GET | `/communication/frequent/<user_id>?limit=10` | Most-used phrases |
| POST | `/communication/favorites/<user_id>` | Mark an icon as favorite |

**POST /communication/select** — Body:
```json
{ "user_id": "664f...", "icon_id": "water", "language": "en" }
```
Response:
```json
{ "icon_id": "water", "phrase_text": "I am thirsty, I need water.", "language": "en" }
```

---
## AI Prediction
| Method | Endpoint | Description |
|---|---|---|
| GET | `/predict/<user_id>` | Top-3 predicted next icons/phrases |

Response:
```json
{
  "user_id": "664f...",
  "predictions": [
    { "icon_id": "water", "score": 0.53, "phrase_text": "I am thirsty, I need water." },
    { "icon_id": "food", "score": 0.31, "phrase_text": "I am hungry, I want food." },
    { "icon_id": "help", "score": 0.12, "phrase_text": "I need help right now." }
  ]
}
```

---
## Emergency
| Method | Endpoint | Description |
|---|---|---|
| POST | `/emergency/sos` | Trigger SOS: log + notify caregiver |
| GET | `/emergency/logs/<user_id>` | List past emergency logs |

**POST /emergency/sos** — Body:
```json
{ "user_id": "664f...", "latitude": 13.0827, "longitude": 80.2707 }
```
Response:
```json
{ "message": "SOS triggered", "log_id": "665a...", "caregiver_notified": true }
```

---
## Text-to-Speech
| Method | Endpoint | Description |
|---|---|---|
| POST | `/tts/speak` | Server-side Google Cloud TTS (fallback to on-device flutter_tts) |

Body: `{ "text": "I am hungry, I want food.", "language": "en" }`
Response: `{ "audio_base64": "...", "mime_type": "audio/mp3" }`

---
## Error Format
All errors return: `{ "error": "description of what went wrong" }` with an
appropriate 4xx/5xx status code.
