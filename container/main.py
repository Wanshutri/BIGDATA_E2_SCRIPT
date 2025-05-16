from fastapi import FastAPI
from google.cloud import storage, pubsub_v1
import pandas as pd
import json
import os
from io import BytesIO

# Configura tus variables
BUCKET_NAME = os.environ.get("BUCKET_NAME")
PARQUET_FILE = "yellow_tripdata_2022-01.parquet"
PUBSUB_TOPIC = os.environ.get("TOPIC_ID")

app = FastAPI()

# Inicializa los clientes de GCP
storage_client = storage.Client()
publisher = pubsub_v1.PublisherClient()

def leer_parquet_desde_gcs(bucket_name: str, file_name: str) -> pd.DataFrame:
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    parquet_bytes = blob.download_as_bytes()
    df = pd.read_parquet(BytesIO(parquet_bytes))
    return df

def publicar_a_pubsub(data: dict):
    json_data = json.dumps(data).encode("utf-8")
    future = publisher.publish(PUBSUB_TOPIC, json_data)
    return future.result()

@app.get("/")
def leer_y_publicar():
    try:
        df = leer_parquet_desde_gcs(BUCKET_NAME, PARQUET_FILE)
        registros = df.to_dict(orient="records")

        # Envía cada fila como un mensaje individual a Pub/Sub
        for fila in registros:
            publicar_a_pubsub(fila)

        return {"status": "Publicado en Pub/Sub", "filas": len(registros)}
    except Exception as e:
        return {"error": str(e)}
