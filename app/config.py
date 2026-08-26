"""
Application Configuration Module
Handles environment variables and configuration settings.
"""

import os

# Load local environment if available
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


class Config:
    """Base application configuration."""

    APP_NAME = os.getenv("APP_NAME", "DevSecOps Flask App")
    APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
    ENVIRONMENT = os.getenv("ENVIRONMENT", "production")
    DEBUG = os.getenv("DEBUG", "False").lower() in ("true", "1", "t")
    PORT = int(os.getenv("PORT", "5000"))
    HOST = os.getenv("HOST", "0.0.0.0")  # nosec B104
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-insecure-secret-key-change-in-prod")
    JSON_SORT_KEYS = False


class DevelopmentConfig(Config):
    """Development configuration."""

    DEBUG = True
    ENVIRONMENT = "development"


class TestingConfig(Config):
    """Testing configuration."""

    TESTING = True
    DEBUG = True
    ENVIRONMENT = "testing"


class ProductionConfig(Config):
    """Production configuration."""

    DEBUG = False
    ENVIRONMENT = "production"


config_by_name = {
    "development": DevelopmentConfig,
    "testing": TestingConfig,
    "production": ProductionConfig,
}
