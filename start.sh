read -p "Ingrese el Project ID: " PROJECT_ID
export GCP_PROJECT_ID="$PROJECT_ID"

read -p "Ingrese el nombre del bucket a crear (debe ser único globalmente): " BUCKET_NAME
export BUCKET_NAME="$BUCKET_NAME"

read -p "Ingrese el nombre del topico: " TOPIC_NAME
export TOPIC_NAME="$TOPIC_NAME"

read -p "Ingrese el nombre del trigger: " TRIGGER_NAME
export TRIGGER_NAME="$TRIGGER_NAME"

gsutil mb -l "us-central1" -p "$GCP_PROJECT_ID" "gs://$BUCKET_NAME/"

gcloud pubsub topics create "$TOPIC_NAME" --project="$GCP_PROJECT_ID"

gcloud scheduler jobs create pubsub $TRIGGER_NAME \
  --schedule="* * * * *" \
  --time-zone="America/Santiago" \
  --topic=$TOPIC_NAME \
  --message-body='{"trigger": "start"}' \
  --region=us-central1

PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@dataflow-service-producer-prod.iam.gserviceaccount.com" \
  --role="roles/dataflow.serviceAgent"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:service-${PROJECT_NUMBER}@dataflow-service-producer-prod.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

pip install -r requirements.txt

python3 main.py