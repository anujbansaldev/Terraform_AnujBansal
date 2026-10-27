"""Small Flask API used by all assignment deployment stages."""

from datetime import datetime, timezone
import os
import re

from flask import Flask, jsonify, request


app = Flask(__name__)
EMAIL_PATTERN = re.compile(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")


@app.get("/api/health")
def health():
    return jsonify({"status": "ok", "service": "flask-backend"})


@app.post("/api/submit")
def submit():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get("name", "")).strip()
    email = str(payload.get("email", "")).strip()
    message = str(payload.get("message", "")).strip()

    errors = {}
    if not name:
        errors["name"] = "Name is required."
    elif len(name) > 100:
        errors["name"] = "Name must be 100 characters or fewer."
    if not EMAIL_PATTERN.match(email):
        errors["email"] = "Enter a valid email address."
    if not message:
        errors["message"] = "Message is required."
    elif len(message) > 2000:
        errors["message"] = "Message must be 2000 characters or fewer."

    if errors:
        return jsonify({"error": "Validation failed", "fields": errors}), 400

    return jsonify(
        {
            "message": "Thanks! Your message was received.",
            "submission": {"name": name, "email": email, "message": message},
            "received_at": datetime.now(timezone.utc).isoformat(),
        }
    ), 201


if __name__ == "__main__":
    app.run(
        host=os.getenv("FLASK_HOST", "0.0.0.0"),
        port=int(os.getenv("FLASK_PORT", "5000")),
        debug=False,
    )
