#!/bin/bash

gcloud auth application-default login
read -p "Por favor, termina la autenticacion y presiona Enter para continuar..."

# Solicitar al usuario los valores
read -p "Ingrese el Username: " USERNAME
read -p "Ingrese el Password: " PASSWORD
read -p "Ingrese el Project ID: " PROJECT_ID
read -p "Ingrese el nombre del Topic de Pub/Sub: " TOPIC_ID
read -p "Ingrese el nombre del bucket a crear (debe ser único globalmente): " BUCKET_NAME

# Exportar variables de entorno
export GCP_USERNAME="$USERNAME"
export GCP_PASSWORD="$PASSWORD"
export GCP_PROJECT_ID="$PROJECT_ID"
export TOPIC_NAME="$TOPIC_ID"
export TOPIC_ID="projects/$GCP_PROJECT_ID/topics/$TOPIC_NAME"
export BUCKET_NAME="$BUCKET_NAME"
export GCP_REGION="us-central1"

# Mostrar información
echo "========================================="
echo "Variables de entorno configuradas:"
echo "GCP_USERNAME=$GCP_USERNAME"
echo "GCP_PASSWORD=[oculto]"
echo "GCP_PROJECT_ID=$GCP_PROJECT_ID"
echo "TOPIC_ID=$TOPIC_ID"
echo "BUCKET_NAME=$BUCKET_NAME"
echo "GCP_REGION=$GCP_REGION"
echo "========================================="

echo "Creando bucket '$BUCKET_NAME' en la región '$GCP_REGION'..."
gsutil mb -l "$GCP_REGION" -p "$GCP_PROJECT_ID" "gs://$BUCKET_NAME/"

# Esperar subida de .parquet manualmente
read -p "Por favor, sube el archivo .parquet al bucket '$BUCKET_NAME' y presiona Enter para continuar..."

# Crear el topic
echo "Creando el topic '$TOPIC_ID' en el proyecto '$GCP_PROJECT_ID'..."
gcloud pubsub topics create "$TOPIC_NAME" --project="$GCP_PROJECT_ID"

# Construir imagen Docker
echo "Construyendo imagen Docker..."
docker build -t taxi-ingesta ./container

# Ejecutar contenedor en segundo plano
#echo "Ejecutando contenedor en segundo plano..."
#docker run -d -p 8080:8080 \
#  -e TOPIC_ID="$TOPIC_ID" \
#  -e BUCKET_NAME="$BUCKET_NAME" \
#  taxi-ingesta

#echo "Contenedor iniciado en segundo plano. Accede en http://localhost:8080"

# Etiquetar la imagen para subir a Google Container Registry
docker tag taxi-ingesta gcr.io/$GCP_PROJECT_ID/taxi-ingesta:v1

# Empujar a GCR
docker push gcr.io/$GCP_PROJECT_ID/taxi-ingesta:v1

# Subir la imagen a Google Container Registry
gcloud run deploy taxi-ingesta \
  --image gcr.io/$GCP_PROJECT_ID/taxi-ingesta:v1 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated

# Obtener la URL del servicio desplegado
CLOUD_RUN_URL=$(gcloud run services describe taxi-ingesta \
  --platform managed \
  --region "$GCP_REGION" \
  --format='value(status.url)')

echo "URL del servicio Cloud Run: $CLOUD_RUN_URL"

# Crear una suscripción push al tópico
SUBSCRIPTION_NAME="taxi-ingesta-sub"
echo "Creando suscripción push '$SUBSCRIPTION_NAME' al tópico '$TOPIC_ID'..."

gcloud pubsub subscriptions create "$SUBSCRIPTION_NAME" \
  --topic="$TOPIC_NAME" \
  --push-endpoint="$CLOUD_RUN_URL" \
  --project="$GCP_PROJECT_ID"

echo "Suscripción creada y conectada a Cloud Run. Pub/Sub enviará eventos a $CLOUD_RUN_URL"
