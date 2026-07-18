"""
Tests for Caregiver Management & SOS FCM Alerts system.
Run with: pytest backend/tests/test_fcm_caregiver_endpoints.py -v
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
import mongomock
from unittest.mock import patch
from bson import ObjectId


@pytest.fixture
def app():
    with patch("pymongo.MongoClient", mongomock.MongoClient):
        from app import create_app
        flask_app = create_app()
        flask_app.config["TESTING"] = True
        yield flask_app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def seeded_user(client):
    res = client.post("/api/users", json={"name": "Test User", "preferred_language": "en"})
    return res.get_json()["_id"]


def test_caregiver_crud(client, seeded_user):
    # 1. Add caregiver
    res = client.post(f"/api/users/{seeded_user}/caregivers", json={
        "name": "Jane Doe",
        "relationship": "Mother",
        "phone": "+1234567890",
        "email": "jane@example.com",
    })
    assert res.status_code == 201
    cg = res.get_json()
    assert cg["name"] == "Jane Doe"
    assert cg["relationship"] == "Mother"
    assert "_id" in cg
    cg_id = cg["_id"]

    # 2. Get caregivers
    res = client.get(f"/api/users/{seeded_user}/caregivers")
    assert res.status_code == 200
    cgs = res.get_json()
    assert len(cgs) == 1
    assert cgs[0]["name"] == "Jane Doe"

    # 3. Edit caregiver
    res = client.put(f"/api/users/{seeded_user}/caregivers/{cg_id}", json={
        "relationship": "Guardian",
        "notifications_enabled": False
    })
    assert res.status_code == 200

    # Verify update
    res = client.get(f"/api/users/{seeded_user}/caregivers")
    cgs = res.get_json()
    assert cgs[0]["relationship"] == "Guardian"
    assert cgs[0]["notifications_enabled"] is False

    # 4. Register Token
    res = client.post(f"/api/users/{seeded_user}/caregivers/{cg_id}/register-token", json={
        "fcm_token": "mock-token-xyz"
    })
    assert res.status_code == 200

    # Verify token
    res = client.get(f"/api/users/{seeded_user}/caregivers")
    cgs = res.get_json()
    assert cgs[0]["fcm_token"] == "mock-token-xyz"

    # 5. Delete caregiver
    res = client.delete(f"/api/users/{seeded_user}/caregivers/{cg_id}")
    assert res.status_code == 200

    res = client.get(f"/api/users/{seeded_user}/caregivers")
    assert len(res.get_json()) == 0


def test_multiple_caregivers_sos_and_status(client, seeded_user):
    # Add two caregivers
    res1 = client.post(f"/api/users/{seeded_user}/caregivers", json={
        "name": "Caregiver Alpha",
        "relationship": "Father",
        "phone": "+11111111",
        "email": "alpha@example.com",
        "fcm_token": "token-alpha"
    })
    cg1_id = res1.get_json()["_id"]

    res2 = client.post(f"/api/users/{seeded_user}/caregivers", json={
        "name": "Caregiver Beta",
        "relationship": "Doctor",
        "phone": "+22222222",
        "email": "beta@example.com",
        "fcm_token": "token-beta"
    })
    cg2_id = res2.get_json()["_id"]

    # Trigger SOS
    res_sos = client.post("/api/emergency/sos", json={
        "user_id": seeded_user,
        "latitude": 12.97,
        "longitude": 77.59,
        "message": "Immediate help needed!"
    })
    assert res_sos.status_code == 200
    sos_res = res_sos.get_json()
    assert "log_id" in sos_res
    alert_id = sos_res["log_id"]

    assert len(sos_res["caregiver_statuses"]) == 2

    # Fetch alerts for user
    res_alerts = client.get(f"/api/emergency/alerts/{seeded_user}")
    assert res_alerts.status_code == 200
    alerts = res_alerts.get_json()
    assert len(alerts) >= 1
    recent_alert = alerts[0]
    assert recent_alert["user_name"] == "Test User"
    assert recent_alert["alert_status"] == "Sent"

    # Update single caregiver alert status to Delivered
    res_up = client.put(f"/api/emergency/alerts/{alert_id}/status", json={
        "caregiver_id": cg1_id,
        "status": "Delivered"
    })
    assert res_up.status_code == 200

    # Verify status changed
    res_alerts = client.get(f"/api/emergency/alerts/{seeded_user}")
    recent_alert = res_alerts.get_json()[0]
    assert recent_alert["alert_status"] == "Delivered"
    cg1_notif = next(c for c in recent_alert["caregiver_notifications"] if c["caregiver_id"] == cg1_id)
    assert cg1_notif["status"] == "Delivered"
