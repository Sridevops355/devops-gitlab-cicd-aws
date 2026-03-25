from flask import Flask, jsonify
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "development")


@app.route("/")
def index():
    return jsonify({
        "message": "DevOps GitLab CI/CD Demo App",
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "status": "running"
    })


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "version": APP_VERSION}), 200


@app.route("/ready")
def ready():
    return jsonify({"status": "ready"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5000))
    debug = ENVIRONMENT == "development"
    logger.info(f"Starting app v{APP_VERSION} on port {port} [{ENVIRONMENT}]")
    app.run(host="0.0.0.0", port=port, debug=debug)
