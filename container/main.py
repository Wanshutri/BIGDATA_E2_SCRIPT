import os
import json
import requests
import logging
from flask import Flask
from google.cloud import pubsub_v1
from google.api_core.exceptions import GoogleAPICallError, RetryError

# Configuración de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Inicializamos Flask
app = Flask(__name__)

# API Key y configuración
API_KEY = os.environ.get("API_KEY")
project_id = os.environ.get("GCP_PROJECT_ID")
topic_id = os.environ.get("TOPIC_ID")

# Cliente Pub/Sub
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project_id, topic_id)

# Lista de ciudades a consultar
CITIES = [
    "Arica", "Iquique", "Santiago", "Valparaiso",
    "Rancagua", "Concepcion", "Chillan", "Osorno"
]

def get_weather_data(city):
    try:
        url = "http://api.weatherapi.com/v1/current.json"
        params = {
            "key": API_KEY,
            "q": city,
            "aqi": "no"
        }
        response = requests.get(url, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching weather data for {city}: {e}")
        raise

def publish_to_pubsub(data):
    try:
        # Convertimos el diccionario a JSON válido
        message = json.dumps(data).encode('utf-8')

        # Publicamos el mensaje en Pub/Sub
        future = publisher.publish(topic_path, message)
        future.result()

        logger.info(f"Message for {data.get('location', {}).get('name')} published successfully.")
    except (GoogleAPICallError, RetryError) as e:
        logger.error(f"Error publishing message to Pub/Sub: {e}")
        raise

@app.route('/', methods=['POST', 'GET'])
def main():
    try:
        for city in CITIES:
            weather_data = get_weather_data(city)
            publish_to_pubsub(weather_data)
        return 'Success', 200
    except Exception as e:
        logger.error(f"Error in main function: {e}")
        return f"Error: {e}", 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))