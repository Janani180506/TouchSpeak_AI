# TouchSpeak AI — MongoDB Schema (MongoDB Atlas)

Database name: `touchspeak`

## 1. `users`
Stores the non-verbal individual's profile and caregiver info.

```json
{
  "_id": "ObjectId",
  "name": "Arun Kumar",
  "age": 9,
  "preferred_language": "ta",
  "caregiver": {
    "name": "Meena Kumar",
    "phone": "+91-9876543210",
    "email": "meena@example.com",
    "fcm_token": "d7x...device-token"
  },
  "emergency_contacts": [
    { "name": "Dr. Ramesh", "phone": "+91-9000000000", "relation": "Doctor" }
  ],
  "created_at": "ISODate",
  "updated_at": "ISODate"
}
```
Indexes:
- `{ "caregiver.phone": 1 }`

## 2. `communication_history`
Every icon tap, in order — this is what the AI predictor learns from.

```json
{
  "_id": "ObjectId",
  "user_id": "ObjectId -> users._id",
  "icon_id": "water",
  "language": "ta",
  "phrase_text": "எனக்கு தாகமாக இருக்கிறது, தண்ணீர் வேண்டும்.",
  "timestamp": "ISODate"
}
```
Indexes:
- `{ "user_id": 1, "timestamp": -1 }`   (fast recent-history lookups)

## 3. `frequently_used_phrases`
One aggregate document per (user, icon) pair — powers "Frequently Used" & favorites screens.

```json
{
  "_id": "ObjectId",
  "user_id": "ObjectId -> users._id",
  "icon_id": "food",
  "phrase_text": "I am hungry, I want food.",
  "use_count": 42,
  "is_favorite": true,
  "last_used": "ISODate"
}
```
Indexes:
- `{ "user_id": 1, "icon_id": 1 }` (unique compound, upsert target)
- `{ "user_id": 1, "use_count": -1 }`

## 4. `emergency_logs`
```json
{
  "_id": "ObjectId",
  "user_id": "ObjectId -> users._id",
  "message": "This is an emergency, I need immediate help.",
  "location": { "type": "Point", "coordinates": [80.2707, 13.0827] },
  "caregiver_notified": true,
  "timestamp": "ISODate"
}
```
Indexes:
- `{ "user_id": 1, "timestamp": -1 }`
- `{ "location": "2dsphere" }` (geo queries, e.g. "alerts near a caregiver")

## 5. `user_preferences`
```json
{
  "_id": "ObjectId",
  "user_id": "ObjectId -> users._id",
  "preferred_language": "ta",
  "theme": "high-contrast",
  "icon_size": "large",
  "voice_speed": 1.0,
  "updated_at": "ISODate"
}
```
Indexes:
- `{ "user_id": 1 }` (unique)
