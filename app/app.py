"""
Main Flask Application Module
Implements REST API endpoints, health checking, and web dashboard.
"""

from datetime import datetime, timezone
import os
import time
from typing import Any, Dict, Tuple
from flask import Flask, jsonify, render_template, request, Response
import psutil

from app.config import Config, config_by_name

# Track application start time for uptime calculations
START_TIME = time.time()


def create_app(config_name: str = None) -> Flask:
    """
    Application factory for creating and configuring the Flask instance.

    Args:
        config_name: String matching environment (development, testing, production).

    Returns:
        Configured Flask application instance.
    """
    if config_name is None:
        config_name = os.getenv("FLASK_ENV", "production")

    app = Flask(__name__)
    config_class = config_by_name.get(config_name, Config)
    app.config.from_object(config_class)

    # Security Response Headers Middleware
    @app.after_request
    def set_security_headers(response: Response) -> Response:
        """Inject baseline HTTP security headers."""
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["X-XSS-Protection"] = "1; mode=block"
        response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://cdnjs.cloudflare.com; "
            "font-src 'self' https://fonts.gstatic.com https://cdnjs.cloudflare.com; "
            "script-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; "
            "img-src 'self' data: https:;"
        )
        return response

    @app.route("/", methods=["GET"])
    def index() -> str:
        """Render the application homepage dashboard."""
        uptime_seconds = int(time.time() - START_TIME)
        uptime_formatted = f"{uptime_seconds // 3600}h {(uptime_seconds % 3600) // 60}m {uptime_seconds % 60}s"

        context = {
            "app_name": app.config["APP_NAME"],
            "version": app.config["APP_VERSION"],
            "environment": app.config["ENVIRONMENT"],
            "uptime": uptime_formatted,
            "status": "HEALTHY",
            "host_os": os.name,
            "cpu_usage": f"{psutil.cpu_percent(interval=None)}%",
            "memory_usage": f"{psutil.virtual_memory().percent}%",
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        return render_template("index.html", **context)

    @app.route("/health", methods=["GET"])
    def health_check() -> Tuple[Response, int]:
        """
        Health check endpoint for Docker HEALTHCHECK, AWS Target Groups, and CI/CD validation.

        Returns:
            JSON response containing health status, uptime, and system diagnostics.
        """
        uptime_seconds = round(time.time() - START_TIME, 2)
        memory = psutil.virtual_memory()

        health_data: Dict[str, Any] = {
            "status": "UP",
            "service": app.config["APP_NAME"],
            "version": app.config["APP_VERSION"],
            "environment": app.config["ENVIRONMENT"],
            "uptime_seconds": uptime_seconds,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": {
                "system_memory": {
                    "status": "UP" if memory.percent < 90 else "DEGRADED",
                    "percent_used": memory.percent,
                },
                "system_cpu": {
                    "status": "UP",
                    "percent_used": psutil.cpu_percent(interval=None),
                },
            },
        }
        return jsonify(health_data), 200

    @app.route("/api/status", methods=["GET"])
    def api_status() -> Tuple[Response, int]:
        """
        API endpoint returning comprehensive application runtime status and resource metrics.

        Returns:
            JSON response with detailed system and process metrics.
        """
        process = psutil.Process(os.getpid())
        mem_info = process.memory_info()

        status_payload: Dict[str, Any] = {
            "application": {
                "name": app.config["APP_NAME"],
                "version": app.config["APP_VERSION"],
                "environment": app.config["ENVIRONMENT"],
                "debug": app.config["DEBUG"],
            },
            "system": {
                "cpu_count": psutil.cpu_count(logical=True),
                "cpu_percent": psutil.cpu_percent(interval=None),
                "virtual_memory_percent": psutil.virtual_memory().percent,
                "disk_usage_percent": psutil.disk_usage("/").percent if os.name != "nt" else 0.0,
            },
            "process": {
                "pid": process.pid,
                "memory_rss_bytes": mem_info.rss,
                "memory_rss_mb": round(mem_info.rss / (1024 * 1024), 2),
                "threads": process.num_threads(),
            },
            "server_time": datetime.now(timezone.utc).isoformat(),
            "status": "operational",
        }
        return jsonify(status_payload), 200

    @app.route("/api/info", methods=["GET"])
    def api_info() -> Tuple[Response, int]:
        """
        API endpoint exposing deployment and architectural metadata.

        Returns:
            JSON response with architecture, CI/CD pipeline version, and repository information.
        """
        info_payload: Dict[str, Any] = {
            "application": app.config["APP_NAME"],
            "version": app.config["APP_VERSION"],
            "pipeline": "Reusable GitHub Actions CI/CD Pipeline",
            "security_tools": [
                "SonarQube Static Analysis",
                "Trivy Container & FS Vulnerability Scanner",
                "Snyk Dependency & Container Security",
                "OWASP ZAP Dynamic Application Security Testing",
            ],
            "deployment_target": "AWS EC2 Ubuntu Instance with Docker",
            "request_client": request.remote_addr,
        }
        return jsonify(info_payload), 200

    @app.route("/api/version", methods=["GET"])
    def api_version() -> Tuple[Response, int]:
        """
        Simple version API endpoint.

        Returns:
            JSON response with version and release string.
        """
        return jsonify({"version": app.config["APP_VERSION"], "status": "active"}), 200

    # Error Handlers
    @app.errorhandler(404)
    def handle_not_found(error: Exception) -> Tuple[Response, int]:
        """Handle 404 Resource Not Found errors."""
        if request.path.startswith("/api/"):
            return jsonify({"error": "Resource not found", "status_code": 404, "path": request.path}), 404
        return jsonify({"error": "Page not found", "status_code": 404, "message": str(error)}), 404

    @app.errorhandler(500)
    def handle_internal_server_error(error: Exception) -> Tuple[Response, int]:
        """Handle 500 Internal Server Error."""
        return (
            jsonify(
                {
                    "error": "Internal Server Error",
                    "status_code": 500,
                    "message": "An unexpected error occurred on the server.",
                }
            ),
            500,
        )

    return app


# Root application instance for WSGI servers (Gunicorn)
app = create_app()

if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5000"))
    debug = os.getenv("DEBUG", "True").lower() in ("true", "1", "t")
    app.run(host=host, port=port, debug=debug)
