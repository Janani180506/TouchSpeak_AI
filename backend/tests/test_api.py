"""
Backend test suite. Run with: pytest backend/tests -v
Requires: pip install pytest mongomock
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
import mongomock
from unittest.mock import patch


@pytest.fixture
def app():
    with patch("pymongo.MongoClient", mongomock.MongoClient):
        from app import create_app
        flask_app = create_app()
        yield flask_app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def seeded_user(client):
    res = client.post("/api/users", json={"name": "Test User", "preferred_language": "en"})
    return res.get_json()["_id"]


def test_health(client):
    res = client.get("/api/health")
    assert res.status_code == 200
    assert res.get_json()["status"] == "ok"


def test_create_user_missing_fields(client):
    res = client.post("/api/users", json={"age": 10})
    assert res.status_code == 400


def test_create_user_success(client):
    res = client.post("/api/users", json={"name": "Arun", "preferred_language": "ta"})
    assert res.status_code == 201
    body = res.get_json()
    assert body["name"] == "Arun"
    assert body["preferred_language"] == "ta"


def test_list_icons(client):
    res = client.get("/api/communication/icons")
    assert res.status_code == 200
    body = res.get_json()
    assert "food" in body["phrases"]
    assert "needs" in body["categories"]


def test_select_unknown_icon(client, seeded_user):
    res = client.post(
        "/api/communication/select",
        json={"user_id": seeded_user, "icon_id": "not_a_real_icon", "language": "en"},
    )
    assert res.status_code == 404


def test_select_icon_logs_history(client, seeded_user):
    res = client.post(
        "/api/communication/select",
        json={"user_id": seeded_user, "icon_id": "food", "language": "en"},
    )
    assert res.status_code == 200
    assert "hungry" in res.get_json()["phrase_text"]

    history = client.get(f"/api/communication/history/{seeded_user}").get_json()
    assert len(history) == 1
    assert history[0]["icon_id"] == "food"


def test_predict_cold_start(client, seeded_user):
    res = client.get(f"/api/predict/{seeded_user}")
    assert res.status_code == 200
    preds = res.get_json()["predictions"]
    assert len(preds) == 3


def test_predict_learns_pattern(client, seeded_user):
    # Simulate a repeated pattern: food, water, food, water...
    for _ in range(5):
        client.post("/api/communication/select", json={"user_id": seeded_user, "icon_id": "food", "language": "en"})
        client.post("/api/communication/select", json={"user_id": seeded_user, "icon_id": "water", "language": "en"})

    res = client.get(f"/api/predict/{seeded_user}")
    preds = res.get_json()["predictions"]
    top_icons = [p["icon_id"] for p in preds]
    assert "food" in top_icons or "water" in top_icons


def test_emergency_sos_missing_location(client, seeded_user):
    res = client.post("/api/emergency/sos", json={"user_id": seeded_user})
    assert res.status_code == 400


def test_emergency_sos_success(client, seeded_user):
    res = client.post(
        "/api/emergency/sos",
        json={"user_id": seeded_user, "latitude": 13.08, "longitude": 80.27},
    )
    assert res.status_code == 200
    body = res.get_json()
    assert "log_id" in body

    logs = client.get(f"/api/emergency/logs/{seeded_user}").get_json()
    assert len(logs) == 1
