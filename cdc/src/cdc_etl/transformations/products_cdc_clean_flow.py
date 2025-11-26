from pyspark import pipelines as dp
from pyspark.sql.types import StructType, StructField, StringType, LongType, TimestampType
from pyspark.sql.functions import from_json, col, to_timestamp

# The schema indicates 'created_at' and 'updated_at' are coming as strings
# with the Debezium 'ZonedTimestamp' format (e.g., "2023-10-27T10:15:30Z").

dp.create_streaming_table(
    name="products_cdc_clean",
    comment="Cleaned product data with dynamic schema handling.",
    expect_all_or_drop={
        "valid_product_id": "product_id IS NOT NULL",
        "valid_product_name": "product_name IS NOT NULL",
        "valid_product_type": "product_type IN ('SVOD', 'Linear', 'TVOD')",
        # Note: Validations should only reference columns that exist in the *output* schema.
        "valid_op": "op IN ('c', 'u', 'd', 't')",
    },
)


@dp.append_flow(target="products_cdc_clean", name="products_cdc_clean_flow")
def products_cdc_clean_flow():
    return spark.readStream.table("products_cdc_bronze").select(
        col("after.*"), col("op"), col("source.ts_ms").alias("ts_ms")
    )
