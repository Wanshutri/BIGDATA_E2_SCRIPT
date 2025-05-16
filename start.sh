#!/bin/bash

# Solicitar al usuario los valores
read -p "Ingrese el Username: " USERNAME
read -p "Ingrese el Password: " PASSWORD
read -p "Ingrese el Project ID: " PROJECT_ID
read -p "Ingrese la API KEY: " API_KEY
read -p "Ingrese el nombre del Topic de Pub/Sub: " TOPIC_ID
read -p "Ingrese el nombre del bucket a crear (debe ser único globalmente): " BUCKET_NAME

# Exportar variables de entorno
export GCP_USERNAME="$USERNAME"
export GCP_PASSWORD="$PASSWORD"
export GCP_PROJECT_ID="$PROJECT_ID"
export API_KEY="$API_KEY"
export TOPIC_ID="projects/$GCP_PROJECT_ID/topics/$TOPIC_ID"
export BUCKET_NAME="$BUCKET_NAME"
export GCP_REGION="us-central1"

# Mostrar información
echo "========================================="
echo "Variables de entorno configuradas:"
echo "GCP_USERNAME=$GCP_USERNAME"
echo "GCP_PASSWORD=[oculto]"
echo "GCP_PROJECT_ID=$GCP_PROJECT_ID"
echo "API_KEY=$API_KEY"
echo "TOPIC_ID=$TOPIC_ID"
echo "BUCKET_NAME=$BUCKET_NAME"
echo "GCP_REGION=$GCP_REGION"
echo "========================================="

echo "Creando bucket '$BUCKET_NAME' en la región '$GCP_REGION'..."
gsutil mb -l "$GCP_REGION" -p "$GCP_PROJECT_ID" "gs://$BUCKET_NAME/"

# Crear el topic
echo "Creando el topic '$TOPIC_ID' en el proyecto '$GCP_PROJECT_ID'..."
gcloud pubsub topics create "$TOPIC_ID" --project="$GCP_PROJECT_ID"

# Construir imagen Docker
echo "Construyendo imagen Docker..."
docker build -t taxi-ingesta ./container

# Ejecutar contenedor en segundo plano
echo "Ejecutando contenedor en segundo plano..."
docker run -d -p 8080:8080 \
  -e API_KEY="$API_KEY" \
  -e GCP_PROJECT_ID="$GCP_PROJECT_ID" \
  -e TOPIC_ID="$TOPIC_ID" \
  taxi-ingesta

echo "Contenedor iniciado en segundo plano. Accede en http://localhost:8080"

# Etiquetar la imagen para subir a Google Container Registry
docker tag taxi-ingesta gcr.io/$GCP_PROJECT_ID/taxi-ingesta:v1

# Subir la imagen a Google Container Registry
gcloud run deploy taxi-ingesta \
  --image gcr.io/$GCP_PROJECT_ID/taxi-ingesta:v1 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated