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
export TOPIC_ID="$TOPIC_ID"
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
echo "GCP_REGION=$GCP_REGION"
echo "========================================="

echo "Creando bucket '$BUCKET_NAME' en la región '$GCP_REGION'..."
gsutil mb -l "$GCP_REGION" -p "$GCP_PROJECT_ID" "gs://$BUCKET_NAME/"

# Crear el topic
echo "Creando el topic '$TOPIC_ID' en el proyecto '$GCP_PROJECT_ID'..."
gcloud pubsub topics create "$TOPIC_ID" --project="$GCP_PROJECT_ID"

# Construir imagen Docker
echo "Construyendo imagen Docker..."
docker build -t weather-api ./container

# Ejecutar contenedor en segundo plano
echo "Ejecutando contenedor en segundo plano..."
docker run -d -p 8080:8080 \
  -e API_KEY="$API_KEY" \
  -e GCP_PROJECT_ID="$GCP_PROJECT_ID" \
  -e TOPIC_ID="$TOPIC_ID" \
  weather-api

echo "Contenedor iniciado en segundo plano. Accede en http://localhost:8080"

# Clonar repositorio (si no existe)
REPO_DIR="java-docs-samples"

if [ ! -d "$REPO_DIR" ]; then
  echo "Clonando el repositorio de ejemplos de Google Cloud..."
  git clone https://github.com/GoogleCloudPlatform/java-docs-samples.git
else
  echo "Repositorio ya clonado. Usando directorio existente."
fi

cd java-docs-samples/pubsub/streaming-analytics || {
  echo "Error: No se encontró el directorio del ejemplo de Pub/Sub."
  exit 1
}

# Ejecutar ejemplo con Maven y DataflowRunner
echo "Ejecutando el pipeline de ejemplo en Dataflow..."

mvn compile exec:java \
  -Dexec.mainClass=com.examples.pubsub.streaming.PubSubToGcs \
  -Dexec.cleanupDaemonThreads=false \
  -Dexec.args=" \
    --project=$GCP_PROJECT_ID \
    --region=$GCP_REGION \
    --inputTopic=projects/$GCP_PROJECT_ID/topics/$TOPIC_ID \
    --output=gs://$BUCKET_NAME/samples/output \
    --runner=DataflowRunner \
    --windowSize=2 \
    --tempLocation=gs://$BUCKET_NAME/temp"
