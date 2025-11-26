from pyspark import pipelines as dp
from pyspark.sql.types import StructType, StructField, StringType

dbutils.widgets.text(
    "product_raw_dir",
    defaultValue="/Volumes/ott/analytics/landing_zone/product/",
    label="product_raw_dir",
)

product_raw_dir = dbutils.widgets.get("product_raw_dir")

# Define schema for product CDC events
product_schema = StructType(
    [
        StructField("schema", StringType(), True),  # Name of the schema for the event
        StructField(
            "payload", StringType(), True
        ),  # JSON payload containing event data
    ]
)

# Create the target bronze streaming table in ott.analytics schema
dp.create_streaming_table(
    name="products_cdc_bronze",
    comment="Raw product CDC events incrementally ingested from cloud object storage",
)


@dp.append_flow(target="products_cdc_bronze", name="products_bronze_ingest_flow")
def products_bronze_ingest_flow():
    return (
        spark.readStream.format("cloudFiles")
        .option("cloudFiles.format", "json")
        .schema(product_schema)
        .load(product_raw_dir)
    )
