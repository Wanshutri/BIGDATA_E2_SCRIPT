#!/bin/bash

# Paso 0: Activar las APIs necesarias
echo "🔧 Activando APIs necesarias..."
gcloud services enable \
  dataflow.googleapis.com \
  pubsub.googleapis.com \
  cloudscheduler.googleapis.com \
  storage.googleapis.com

# Paso 1: Solicitar datos al usuario
read -p "Ingrese el Project ID: " PROJECT_ID
export GCP_PROJECT_ID="$PROJECT_ID"

read -p "Ingrese el nombre del bucket a crear (debe ser único globalmente): " BUCKET_NAME
export BUCKET_NAME="$BUCKET_NAME"

read -p "Ingrese el nombre del topico: " TOPIC_NAME
export TOPIC_NAME="$TOPIC_NAME"

read -p "Ingrese el nombre del trigger: " TRIGGER_NAME
export TRIGGER_NAME="$TRIGGER_NAME"

# Paso 2: Crear bucket
gsutil mb -l "us-central1" -p "$GCP_PROJECT_ID" "gs://$BUCKET_NAME/"

# Paso 3: Crear tópico de Pub/Sub
gcloud pubsub topics create "$TOPIC_NAME" --project="$GCP_PROJECT_ID"

# Paso 4: Obtener el número del proyecto
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Paso 5: Dar permisos al service account de Dataflow (solo si ya existe tras habilitar API)
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@dataflow-service-producer-prod.iam.gserviceaccount.com" \
  --role="roles/dataflow.serviceAgent"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@dataflow-service-producer-prod.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

# Paso 6: Crear el job de Cloud Scheduler
gcloud scheduler jobs create pubsub "$TRIGGER_NAME" \
  --schedule="* * * * *" \
  --time-zone="America/Santiago" \
  --topic="$TOPIC_NAME" \
  --message-body='{"trigger": "start"}' \
  --location="us-central1" \
  --project="$PROJECT_ID"

# Paso 7: Instalar dependencias (si estás usando Python)
pip install -r requirements.txt

# Paso 8: Ejecutar código
python3 main.py