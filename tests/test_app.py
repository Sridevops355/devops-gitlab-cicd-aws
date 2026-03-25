import pytest
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "../app"))
from app import app


@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_index_returns_json(client):
    response = client.get("/")
    data = response.get_json()
    assert data is not None
    assert "message" in data
    assert "version" in data
    assert "status" in data


def test_health_check_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_check_returns_healthy(client):
    response = client.get("/health")
    data = response.get_json()
    assert data["status"] == "healthy"


def test_ready_check_returns_200(client):
    response = client.get("/ready")
    assert response.status_code == 200


def test_app_version_in_response(client):
    response = client.get("/")
    data = response.get_json()
    assert "version" in data


def test_environment_in_response(client):
    response = client.get("/")
    data = response.get_json()
    assert "environment" in data
