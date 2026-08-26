"""
Pytest Fixtures and Global Configuration for Testing.
"""

import pytest
from flask import Flask
from flask.testing import FlaskClient

from app.app import create_app


@pytest.fixture
def app() -> Flask:
    """Create and configure a testing Flask app instance."""
    app_instance = create_app("testing")
    return app_instance


@pytest.fixture
def client(app: Flask) -> FlaskClient:
    """Create a test client fixture."""
    return app.test_client()


@pytest.fixture
def runner(app: Flask):
    """Create a test CLI runner fixture."""
    return app.test_cli_runner()
