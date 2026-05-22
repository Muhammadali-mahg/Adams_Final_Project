from flask import Flask, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # allows frontend (HTML) to access backend safely

# -------------------------------
# SAMPLE ROUTE DATA (TEST MODE)
# -------------------------------
route_data = {
    "coordinates": [
        [37.5670, 126.9779],   # Start (Seoul City Hall area)
        [37.5690, 126.9790],
        [37.5750, 126.9820],
        [37.4979, 127.0276]    # End (Gangnam area)
    ]
}

# -------------------------------
# API: GET ROUTE
# -------------------------------
@app.route("/route", methods=["GET"])
def get_route():
    return jsonify(route_data)

# -------------------------------
# FUTURE: EMOTION ROUTE (READY HOOK)
# -------------------------------
@app.route("/route/<emotion>", methods=["GET"])
def get_emotion_route(emotion):
    """
    Future upgrade:
    emotion = calm | stressed | sleepy | angry
    """

    if emotion == "calm":
        data = route_data  # later we can modify for scenic route

    elif emotion == "stressed":
        data = route_data  # later shortest / fastest route

    elif emotion == "sleepy":
        data = route_data  # later safer/main roads only

    elif emotion == "angry":
        data = route_data  # later fastest route

    else:
        data = route_data

    return jsonify({
        "emotion": emotion,
        "coordinates": data["coordinates"]
    })

# -------------------------------
# RUN SERVER
# -------------------------------
if __name__ == "__main__":
    print("🚗 ADAMS Navigation Server Running on http://127.0.0.1:5000")
    app.run(debug=True, port=5000)