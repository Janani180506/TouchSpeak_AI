import os
from pymongo import MongoClient
from dotenv import load_dotenv

load_dotenv()
mongo_uri = os.getenv("MONGO_URI", "mongodb://localhost:27017/touchspeak")
client = MongoClient(mongo_uri)
db = client.get_default_database()

print("MONGO_URI:", mongo_uri)
print("Database name:", db.name)
print("Collections:", db.list_collection_names())

user_col = db.get_collection("users")
print("Total users:", user_col.count_documents({}))
for user in user_col.find():
    print(f"\nUser: {user.get('name')} (_id: {user.get('_id')})")
    caregivers = user.get("caregivers", [])
    print(f"Caregivers list ({len(caregivers)}):")
    for cg in caregivers:
        print(f"  - Name: {cg.get('name')}, Email: {cg.get('email')}, FCM Token: {cg.get('fcm_token')}, Enabled: {cg.get('notifications_enabled')}")

alert_col = db.get_collection("emergency_logs")
print("\nTotal emergency_logs:", alert_col.count_documents({}))
for log in alert_col.find().sort("_id", -1).limit(3):
    print(f"Alert ID: {log.get('_id')}")
    print(f"  Timestamp: {log.get('timestamp')}")
    print(f"  User Name: {log.get('user_name')}")
    print(f"  Alert Status: {log.get('alert_status')}")
    print(f"  Caregiver Notifs: {log.get('caregiver_notifications')}")
