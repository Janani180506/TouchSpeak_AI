"""
Unit tests for Caregiver Management System.
Run with: pytest backend/tests/test_caregiver.py -v
"""
import sys
import os
import io
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
        yield flask_app


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def seeded_user(client):
    res = client.post("/api/users", json={"name": "Test User", "preferred_language": "en"})
    return res.get_json()["_id"]


def test_category_crud_and_validations(client):
    # 1. Create a category
    res = client.post("/api/communication/categories", json={
        "name": "Feelings",
        "icon": "mood",
        "display_order": 5
    })
    assert res.status_code == 201
    cat = res.get_json()
    assert cat["name"] == "Feelings"
    assert cat["icon"] == "mood"
    cat_id = cat["_id"]

    # 2. Try to create duplicate category (case insensitive name)
    res_dup = client.post("/api/communication/categories", json={
        "name": "feelings",
        "icon": "mood"
    })
    assert res_dup.status_code == 400
    assert "already exists" in res_dup.get_json()["error"]

    # 3. Create another category
    client.post("/api/communication/categories", json={
        "name": "Food Options",
        "icon": "restaurant"
    })

    # 4. Fetch all categories
    res_get = client.get("/api/communication/categories")
    assert res_get.status_code == 200
    cats = res_get.get_json()
    # At least Feelings, Food Options and seeded categories
    cat_names = [c["name"] for c in cats]
    assert "Feelings" in cat_names
    assert "Food Options" in cat_names

    # 5. Update category name to duplicate should fail
    res_up_fail = client.put(f"/api/communication/categories/{cat_id}", json={
        "name": "Food Options"
    })
    assert res_up_fail.status_code == 400

    # 6. Update category successfully
    res_up = client.put(f"/api/communication/categories/{cat_id}", json={
        "name": "My Feelings",
        "icon": "emoji_emotions"
    })
    assert res_up.status_code == 200
    assert res_up.get_json()["name"] == "My Feelings"

    # 7. Delete category
    res_del = client.delete(f"/api/communication/categories/{cat_id}")
    assert res_del.status_code == 200
    
    # Confirm deletion
    res_get_after = client.get("/api/communication/categories")
    cats_after = res_get_after.get_json()
    assert "My Feelings" not in [c["name"] for c in cats_after]


def test_card_crud_and_validations(client):
    # Create category first
    cat_res = client.post("/api/communication/categories", json={
        "name": "Activities",
        "icon": "sports"
    })
    cat_id = cat_res.get_json()["_id"]

    # 1. Create card success
    res = client.post("/api/communication/cards", json={
        "title": "Play Ball",
        "phrase": "I want to play ball.",
        "category_id": cat_id,
        "translations": {
            "en": "I want to play ball.",
            "ta": "நான் பந்து விளையாட வேண்டும்.",
            "hi": "मैं गेंद खेलना चाहता हूँ।"
        }
    })
    assert res.status_code == 201
    card = res.get_json()
    assert card["title"] == "Play Ball"
    assert card["category_id"] == cat_id
    card_id = card["_id"]

    # 2. Validation: Empty title
    res_err1 = client.post("/api/communication/cards", json={
        "title": "",
        "phrase": "Help",
        "category_id": cat_id
    })
    assert res_err1.status_code == 400

    # 3. Validation: Empty phrase
    res_err2 = client.post("/api/communication/cards", json={
        "title": "Help",
        "phrase": "   ",
        "category_id": cat_id
    })
    assert res_err2.status_code == 400

    # 4. Validation: Invalid category ID
    res_err3 = client.post("/api/communication/cards", json={
        "title": "Help",
        "phrase": "Please help",
        "category_id": "not_an_object_id"
    })
    assert res_err3.status_code == 400

    # 5. Fetch all cards with category filter
    res_get = client.get(f"/api/communication/cards?category_id={cat_id}")
    assert res_get.status_code == 200
    cards = res_get.get_json()
    assert len(cards) == 1
    assert cards[0]["title"] == "Play Ball"

    # 6. Update card test
    res_up = client.put(f"/api/communication/cards/{card_id}", json={
        "title": "Basketball",
        "phrase": "I want to play basketball."
    })
    assert res_up.status_code == 200
    assert res_up.get_json()["title"] == "Basketball"

    # 7. Delete card test
    res_del = client.delete(f"/api/communication/cards/{card_id}")
    assert res_del.status_code == 200
    
    # Confirm deletion
    res_get_del = client.get(f"/api/communication/cards?category_id={cat_id}")
    assert len(res_get_del.get_json()) == 0


def test_card_reordering(client):
    cat_res = client.post("/api/communication/categories", json={
        "name": "Fruits",
        "icon": "apple"
    })
    cat_id = cat_res.get_json()["_id"]

    card1 = client.post("/api/communication/cards", json={
        "title": "Apple",
        "phrase": "I want apple.",
        "category_id": cat_id
    }).get_json()["_id"]

    card2 = client.post("/api/communication/cards", json={
        "title": "Banana",
        "phrase": "I want banana.",
        "category_id": cat_id
    }).get_json()["_id"]

    # Reorder card2 first, then card1
    reorder_res = client.post("/api/communication/cards/reorder", json={
        "card_ids": [card2, card1]
    })
    assert reorder_res.status_code == 200

    # Fetch and check order
    res_get = client.get(f"/api/communication/cards?category_id={cat_id}")
    cards = res_get.get_json()
    assert cards[0]["_id"] == card2
    assert cards[1]["_id"] == card1


def test_favorites(client, seeded_user):
    cat_res = client.post("/api/communication/categories", json={
        "name": "FavsTest",
        "icon": "star"
    })
    cat_id = cat_res.get_json()["_id"]

    card_res = client.post("/api/communication/cards", json={
        "title": "Special Food",
        "phrase": "I want special food.",
        "category_id": cat_id
    })
    card_id = card_res.get_json()["_id"]

    # Add to favorites
    fav_res = client.post(f"/api/communication/favorites/{seeded_user}", json={
        "card_id": card_id,
        "is_favorite": True
    })
    assert fav_res.status_code == 200

    # Fetch favorites
    get_favs = client.get(f"/api/communication/favorites/{seeded_user}")
    assert get_favs.status_code == 200
    fav_cards = get_favs.get_json()
    assert len(fav_cards) == 1
    assert fav_cards[0]["_id"] == card_id

    # Remove from favorites
    unfav_res = client.post(f"/api/communication/favorites/{seeded_user}", json={
        "card_id": card_id,
        "is_favorite": False
    })
    assert unfav_res.status_code == 200

    # Confirm removed
    get_favs_after = client.get(f"/api/communication/favorites/{seeded_user}")
    assert len(get_favs_after.get_json()) == 0


def test_upload_image_invalid_extension(client):
    data = {"image": (io.BytesIO(b"dummy image data"), "file.txt")}
    res = client.post("/api/communication/upload-image", data=data, content_type="multipart/form-data")
    assert res.status_code == 400
    assert "Invalid file type" in res.get_json()["error"]
