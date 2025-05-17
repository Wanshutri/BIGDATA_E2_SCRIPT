import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
import urllib.request
import tempfile
import pyarrow.parquet as pq
import json
import os
import dotenv

dotenv.load_dotenv()

PARQUET_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2016-01.parquet"

PROJECT_ID = os.environ.get("PROJECT_ID")
BUCKET_NAME = os.environ.get("BUCKET_NAME")

class ReadParquet(beam.DoFn):
    def process(self, element):
        with tempfile.NamedTemporaryFile() as tmp:
            urllib.request.urlretrieve(PARQUET_URL, tmp.name)
            table = pq.read_table(tmp.name)
            df = table.to_pandas().sample(n=200)

            for _, row in df.iterrows():
                # Convertimos datetime a string
                for col in df.columns:
                    if hasattr(row[col], 'isoformat'):
                        row[col] = row[col].isoformat()
                yield json.dumps(row.to_dict())

def run():
    options = PipelineOptions(
        streaming=False,
        project=PROJECT_ID,
        region="us-central1",
        temp_location=f"gs://{BUCKET_NAME}/temp"
    )

    output_path = f"gs://{BUCKET_NAME}/output/data"

    with beam.Pipeline(options=options) as p:
        (
            p
            | 'Start' >> beam.Create([None])
            | 'Leer y procesar Parquet' >> beam.ParDo(ReadParquet())
            | 'Escribir en GCS' >> beam.io.WriteToText(output_path, file_name_suffix=".json")
        )

if __name__ == "__main__":
    run()
