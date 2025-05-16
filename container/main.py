from fastapi import FastAPI
from google.cloud import storage, pubsub_v1
import pandas as pd
import json
import os
from io import BytesIO

BUCKET_NAME = os.environ.get("BUCKET_NAME")
PARQUET_FILE = "yellow_tripdata_2022-01.parquet"
PUBSUB_TOPIC = os.environ.get("TOPIC_ID")

app = FastAPI()

storage_client = storage.Client()

# Configurar batch
batch_settings = pubsub_v1.types.BatchSettings(
    max_messages=100,
    max_bytes=1024*1024,
    max_latency=1,
)
publisher = pubsub_v1.PublisherClient(batch_settings=batch_settings)

def leer_parquet_desde_gcs(bucket_name: str, file_name: str) -> pd.DataFrame:
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(file_name)
    parquet_bytes = blob.download_as_bytes()
    df = pd.read_parquet(BytesIO(parquet_bytes))
    return df

@app.get("/")
def leer_y_publicar():
    try:
        df = leer_parquet_desde_gcs(BUCKET_NAME, PARQUET_FILE)
        for col in ["tpep_pickup_datetime", "tpep_dropoff_datetime"]:
            df[col] = df[col].dt.strftime("%Y-%m-%dT%H:%M:%S")

        registros = df.to_dict(orient="records")

        futures = []
        for fila in registros:
            json_data = json.dumps(fila).encode("utf-8")
            future = publisher.publish(PUBSUB_TOPIC, json_data)
            futures.append(future)

        # Esperar a que se publiquen todos
        for future in futures:
            future.result()

        return {"status": "Publicado en Pub/Sub", "filas": len(registros)}

    except Exception as e:
        return {"error": str(e)}
