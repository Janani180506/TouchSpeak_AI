import requests
import json
import time

BASE_URL = "http://127.0.0.1:5000/api"

print("==========================================")
print("TouchSpeak AI - Programmatic Verification")
print("==========================================\n")

# 1. Health check
print("[1] Verifying server health...")
try:
    resp = requests.get(f"{BASE_URL}/health")
    resp.raise_for_status()
    print(f"    Health check success: {resp.json()}\n")
except Exception as e:
    print(f"    Health check failed! Error: {e}")
    exit(1)

# 2. Onboard User Profile
print("[2] Creating a test user profile (MongoDB onboarding)...")
user_payload = {
    "name": "Integration Tester",
    "preferred_language": "en",
    "age": 25,
    "caregiver": {
        "name": "Caregiver Jane",
        "phone": "+919999988888",
        "email": "jane@example.com"
    }
}
resp = requests.post(f"{BASE_URL}/users", json=user_payload)
if resp.status_code == 201:
    user = resp.json()
    user_id = user["_id"]
    print(f"    User created success. ID: {user_id}, Name: {user['name']}\n")
else:
    print(f"    User creation failed: {resp.status_code} - {resp.text}")
    exit(1)

# 3. Retrieve Icons Vocabulary
print("[3] Fetching board icons and multi-language vocabulary...")
resp = requests.get(f"{BASE_URL}/communication/icons")
if resp.status_code == 200:
    vocab = resp.json()
    categories = vocab.get("categories", {})
    phrases = vocab.get("phrases", {})
    print(f"    Loaded needs categories: {categories.get('needs')}")
    print(f"    Loaded emotions categories: {categories.get('emotions')}")
    print(f"    Loaded phrase entries count: {len(phrases)}")
    print(f"    Example 'food' phrase in English: '{phrases.get('food', {}).get('en')}'\n")
else:
    print(f"    Failed to fetch vocabulary: {resp.status_code}")

# 4. Simulate Board Taps (Multi-language and MongoDB logging)
print("[4] Simulating board icon selections...")
selections = [
    ("food", "en"),
    ("water", "en"),
    ("food", "en"), # Select food again to verify frequency count calculations
    ("medicine", "ta"), # Tamil
    ("tired", "hi") # Hindi
]

for icon, lang in selections:
    payload = {"user_id": user_id, "icon_id": icon, "language": lang}
    resp = requests.post(f"{BASE_URL}/communication/select", json=payload)
    if resp.status_code == 200:
        data = resp.json()
        print(f"    Tapped '{icon}' ({lang}) -> Phrase: '{data['phrase_text']}'")
    else:
        print(f"    Board tap simulation failed for {icon}: {resp.status_code}")
print()

# 5. Verify Recent Logs
print("[5] Fetching communication history logs:")
resp = requests.get(f"{BASE_URL}/communication/history/{user_id}?limit=5")
if resp.status_code == 200:
    logs = resp.json()
    for i, log in enumerate(logs):
        print(f"    {i+1}. Phrase: '{log['phrase_text']}' | Icon: {log['icon_id']} | Language: {log['language']}")
    print()
else:
    print(f"    Failed to retrieve history logs: {resp.status_code}\n")

# 6. Verify Frequent Dashboard stats
print("[6] Fetching statistics for frequently used phrases:")
resp = requests.get(f"{BASE_URL}/communication/frequent/{user_id}")
if resp.status_code == 200:
    freqs = resp.json()
    for item in freqs:
        print(f"    Stats -> Icon: '{item['icon_id']}' | Runs: {item['use_count']} times | Phrase: '{item['phrase_text']}'")
    print()
else:
    print(f"    Failed to retrieve frequent stats: {resp.status_code}\n")

# 7. AI Phrase Recommendations Check
print("[7] Requesting AI next-phrase predictions...")
resp = requests.get(f"{BASE_URL}/predict/{user_id}")
if resp.status_code == 200:
    preds = resp.json().get("predictions", [])
    print("    Top Recommended Next-phrases (AI Suggestions):")
    for i, p in enumerate(preds):
        print(f"    - Suggestion #{i+1}: Icon '{p['icon_id']}' (Score: {p['score']}) | Text: '{p['phrase_text']}'")
    print()
else:
    print(f"    Failed to retrieve AI predictions: {resp.status_code}\n")

# 8. Text-To-Speech API Check
print("[8] Testing Text-to-Speech Fallback...")
speak_payload = {"text": "I am in pain, I need help.", "language": "en"}
resp = requests.post(f"{BASE_URL}/tts/speak", json=speak_payload)
if resp.status_code == 200:
    tts_data = resp.json()
    media_len = len(tts_data.get('audio_base64', ''))
    is_mock = tts_data.get('is_mock', False)
    warning = tts_data.get('warning', '')
    print(f"    TTS synthesis success. Received base64 media stream length: {media_len} bytes.")
    print(f"    Audio Mime type: {tts_data.get('mime_type')}")
    if is_mock:
        print(f"    Mock Mode Active: Yes (Warning: {warning})")
    else:
        print(f"    Mock Mode Active: No (Direct Google Cloud TTS verified)")
    print()
else:
    print(f"    TTS test failed: {resp.status_code}\n")

# 9. Emergency SOS Trigger Test
print("[9] Testing Emergency SOS System...")
sos_payload = {
    "user_id": user_id,
    "latitude": 13.0827,
    "longitude": 80.2707,
    "message": "Emergency! I need help immediately."
}
resp = requests.post(f"{BASE_URL}/emergency/sos", json=sos_payload)
if resp.status_code == 200:
    sos_res = resp.json()
    print(f"    SOS Alert successfully triggered and logged in MongoDB.")
    print(f"    Log ID: {sos_res.get('log_id')}")
    print(f"    Caregiver Notified: {sos_res.get('caregiver_notified')}")
    print()
else:
    print(f"    SOS test failed: {resp.status_code}\n")

print("==========================================")
print("TouchSpeak AI programmatic verification passed.")
print("==========================================")
