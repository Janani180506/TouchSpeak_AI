"""
Run once against your MongoDB Atlas cluster to create indexes and (optionally)
seed a demo user. Usage:

    python init_db.py "mongodb+srv://user:pass@cluster0.mongodb.net/touchspeak"
"""
import sys
from datetime import datetime, timezone
from pymongo import MongoClient, ASCENDING, DESCENDING, GEOSPHERE


def main(uri: str):
    client = MongoClient(uri)
    db = client.get_default_database()

    db.users.create_index([("caregiver.phone", ASCENDING)])

    db.communication_history.create_index(
        [("user_id", ASCENDING), ("timestamp", DESCENDING)]
    )

    db.frequently_used_phrases.create_index(
        [("user_id", ASCENDING), ("icon_id", ASCENDING)], unique=True
    )
    db.frequently_used_phrases.create_index([("user_id", ASCENDING), ("use_count", DESCENDING)])

    db.emergency_logs.create_index([("user_id", ASCENDING), ("timestamp", DESCENDING)])
    db.emergency_logs.create_index([("location", GEOSPHERE)])

    db.user_preferences.create_index([("user_id", ASCENDING)], unique=True)

    print("Indexes created successfully.")

    # Seed one demo user for local testing
    demo_user = {
        "name": "Demo User",
        "age": 10,
        "preferred_language": "en",
        "caregiver": {"name": "Demo Caregiver", "phone": "+910000000000", "email": "demo@example.com"},
        "emergency_contacts": [],
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
    }
    existing = db.users.find_one({"name": "Demo User"})
    if not existing:
        result = db.users.insert_one(demo_user)
        print(f"Seeded demo user with _id={result.inserted_id}")
    else:
        print(f"Demo user already exists with _id={existing['_id']}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python init_db.py <MONGO_URI>")
        sys.exit(1)
    main(sys.argv[1])
