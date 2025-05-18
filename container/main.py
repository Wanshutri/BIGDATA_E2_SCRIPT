import os
import pyarrow.parquet as pq
import pyarrow.json as paj
from google.cloud import storage
from flask import Flask, jsonify

app = Flask(__name__)

# Configuración via env vars
BUCKET = os.environ["BUCKET_NAME"]
PARQUET_PATH = "yellow_tripdata_2022-01.parquet"      # fichero local en /tmp si lo descargas
GCS_PREFIX = "dataprep/yellow_tripdata_2022-01"       # carpeta en GCS
POINTER_BLOB = f"{GCS_PREFIX}/pointer.txt"            # donde guardamos el índice

storage_client = storage.Client()
bucket = storage_client.bucket(BUCKET)

def read_pointer():
    blob = bucket.blob(POINTER_BLOB)
    if not blob.exists():
        return 0
    return int(blob.download_as_text())

def write_pointer(idx):
    blob = bucket.blob(POINTER_BLOB)
    blob.upload_from_string(str(idx), content_type="text/plain")

def procesar_siguiente_row_group():
    # 1) Abrir el parquet
    parquet_file = pq.ParquetFile(PARQUET_PATH)
    total_groups = parquet_file.num_row_groups

    # 2) Leer y actualizar puntero
    idx = read_pointer()
    if idx >= total_groups:
        return False, f"Todos los {total_groups} row groups ya procesados."

    # 3) Leer el row group idx
    table = parquet_file.read_row_group(idx)
    # 4) Convertir a NDJSON
    ndjson_bytes = paj.write_json(table, indent=0, use_threads=True).read()

    # 5) Subir a GCS
    destino = f"{GCS_PREFIX}/parte_{idx:03d}.ndjson"
    blob = bucket.blob(destino)
    blob.upload_from_string(ndjson_bytes.decode("utf-8"),
                            content_type="application/x-ndjson")

    # 6) Avanzar el puntero
    write_pointer(idx + 1)
    return True, f"Subido {destino}; next pointer = {idx+1}"

@app.route('/')
def run_job():
    try:
        ok, msg = procesar_siguiente_row_group()
        status = 200 if ok else 204
        return jsonify({"status": ok, "message": msg}), status
    except Exception as e:
        return jsonify({"status": False, "error": str(e)}), 500

if __name__ == "__main__":
    # El parquet debe estar ya descargado en PARQUET_PATH (o descárgalo en /tmp antes)
    port = int(os.environ.get("PORT", 8080))
    app.run(host='0.0.0.0', port=port)
