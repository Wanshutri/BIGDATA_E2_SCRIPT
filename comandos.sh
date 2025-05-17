# 1. Crear un bucket en Google Cloud Storage
export BUCKET_NAME=mi-bucket-de-dataprep

gsutil mb -l us-central1 gs://$BUCKET_NAME

# 2. Subir el código a Cloud Run
gcloud run deploy extraerParquet \
  --source container/. \
  --set-env-vars BUCKET_NAME=$BUCKET_NAME \
  --region us-central1 \
  --allow-unauthenticated

# 3. Obtener la URL del servicio desplegado
SERVICE_URL=$(gcloud run services describe extraerParquet --region us-central1 --format='value(status.url)')

echo "URL del servicio: $SERVICE_URL"

# 4. Crear un trigger en Cloud Scheduler que ejecute la app a las 7:00 UTC todos los días
gcloud scheduler jobs create http extraer-parquet-job \
  --schedule="0 7 * * *" \
  --http-method=GET \
  --uri="$SERVICE_URL" \
  --time-zone="UTC"