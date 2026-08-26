"""
Unit and Integration Tests for Flask Application.
"""

import pytest
from flask.testing import FlaskClient


@pytest.mark.unit
def test_index_page(client: FlaskClient):
    """Test that the homepage renders successfully with HTTP 200."""
    response = client.get("/")
    assert response.status_code == 200
    assert b"DevSecOps" in response.data
    assert b"Health Check" in response.data
    assert b"System Status" in response.data


@pytest.mark.unit
def test_security_headers(client: FlaskClient):
    """Test that standard HTTP security headers are present in response."""
    response = client.get("/")
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("X-XSS-Protection") == "1; mode=block"
    assert "Strict-Transport-Security" in response.headers
    assert "Content-Security-Policy" in response.headers


@pytest.mark.api
def test_health_endpoint(client: FlaskClient):
    """Test the /health endpoint returns valid JSON with status UP."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()
    assert data["status"] == "UP"
    assert "service" in data
    assert "version" in data
    assert "uptime_seconds" in data
    assert "timestamp" in data
    assert "checks" in data
    assert "system_memory" in data["checks"]
    assert "system_cpu" in data["checks"]


@pytest.mark.api
def test_api_status_endpoint(client: FlaskClient):
    """Test the /api/status endpoint returns valid runtime metrics."""
    response = client.get("/api/status")
    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()
    assert data["status"] == "operational"
    assert "application" in data
    assert "system" in data
    assert "process" in data
    assert data["process"]["pid"] > 0
    assert "memory_rss_mb" in data["process"]


@pytest.mark.api
def test_api_info_endpoint(client: FlaskClient):
    """Test the /api/info endpoint returns metadata and security tools."""
    response = client.get("/api/info")
    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()
    assert "security_tools" in data
    assert len(data["security_tools"]) >= 4
    assert "deployment_target" in data


@pytest.mark.api
def test_api_version_endpoint(client: FlaskClient):
    """Test the /api/version endpoint returns version info."""
    response = client.get("/api/version")
    assert response.status_code == 200
    assert response.is_json

    data = response.get_json()
    assert "version" in data
    assert data["status"] == "active"


@pytest.mark.unit
def test_404_not_found_html(client: FlaskClient):
    """Test 404 handler for HTML page routes."""
    response = client.get("/nonexistent-page")
    assert response.status_code == 404
    assert response.is_json
    data = response.get_json()
    assert data["status_code"] == 404


@pytest.mark.unit
def test_404_not_found_api(client: FlaskClient):
    """Test 404 handler for API routes."""
    response = client.get("/api/nonexistent-api")
    assert response.status_code == 404
    assert response.is_json
    data = response.get_json()
    assert data["status_code"] == 404
    assert data["error"] == "Resource not found"


@pytest.mark.unit
def test_500_internal_error_handler():
    """Test 500 error handler returns expected JSON response."""
    from app.app import create_app
    test_app = create_app("production")
    test_app.config["TESTING"] = False
    test_app.config["DEBUG"] = False

    @test_app.route("/error-trigger")
    def error_trigger():
        raise Exception("Simulated test error")

    test_client = test_app.test_client()
    response = test_client.get("/error-trigger")
    assert response.status_code == 500
    assert response.is_json
    data = response.get_json()
    assert data["error"] == "Internal Server Error"
    assert data["status_code"] == 500


@pytest.mark.unit
def test_config_environments():
    """Test configuration classes for dev, test, and prod."""
    from app.config import DevelopmentConfig, TestingConfig, ProductionConfig
    assert DevelopmentConfig.DEBUG is True
    assert TestingConfig.TESTING is True
    assert ProductionConfig.DEBUG is False
