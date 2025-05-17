import os
import requests
import pandas as pd
from google.cloud import storage

def subir_a_gcs(bucket_name, destino_blob, contenido):
    storage_client = storage.Client()
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destino_blob)
    blob.upload_from_string(contenido, content_type='application/json')
    print(f"Archivo JSON subido a gs://{bucket_name}/{destino_blob}")

def descargar_convertir_subir():
    url = "https://bdbatchescuelait.duoc.cl/01/2022"
    local_filename = "yellow_tripdata_2022-01.parquet"

    if not os.path.exists(local_filename):
        print("Descargando archivo...")
        response = requests.get(url, verify=False)
        response.raise_for_status()
        with open(local_filename, "wb") as f:
            f.write(response.content)

    df = pd.read_parquet(local_filename)
    json_data = df.to_json(orient="records", lines=True)

    # Obtener el bucket desde variable de entorno
    bucket_name = os.environ.get("BUCKET_NAME")
    destino_blob = "dataprep/yellow_tripdata_2022-01.json"

    if not bucket_name:
        raise ValueError("La variable de entorno BUCKET_NAME no está definida.")

    subir_a_gcs(bucket_name, destino_blob, json_data)

if __name__ == "__main__":
    descargar_convertir_subir()
