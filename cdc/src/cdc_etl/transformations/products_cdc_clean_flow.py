from pyspark import pipelines as dp
from pyspark.sql.types import StructType, StructField, StringType, LongType, TimestampType
from pyspark.sql.functions import from_json, col, to_timestamp

# The schema indicates 'created_at' and 'updated_at' are coming as strings 
# with the Debezium 'ZonedTimestamp' format (e.g., "2023-10-27T10:15:30Z").

payload_schema = StructType([
    StructField("after", StructType([
        StructField("product_id", StringType()),
        StructField("product_name", StringType()),
        StructField("product_type", StringType()),
        StructField("description", StringType()),
        # Based on the schema provided, these are strings with ZonedTimestamp format in the raw payload
        StructField("created_at", StringType()),
        StructField("updated_at", StringType())
    ])),
    StructField("op", StringType()),
    StructField("source", StructType([
        # The provided schema indicates ts_ms is a 'int64', so use LongType
        StructField("ts_ms", LongType()) 
    ]))
])

dp.create_streaming_table(
    name="products_cdc_clean",
    # The final table columns should match the projected columns in the flow, including the correct TimestampType
    schema=StructType([
        StructField("product_id", StringType()),
        StructField("product_name", StringType()),
        StructField("product_type", StringType()),
        StructField("description", StringType()),
        StructField("created_at", TimestampType()), # Target type is Timestamp
        StructField("updated_at", TimestampType()), # Target type is Timestamp
        StructField("op", StringType()),
        StructField("ts_ms", LongType())
    ]),
    expect_all_or_drop={
        "valid_product_id": "product_id IS NOT NULL",
        "valid_product_name": "product_name IS NOT NULL",
        "valid_product_type": "product_type IN ('SVOD', 'Linear', 'TVOD')",
        "valid_created_at": "created_at IS NOT NULL",
        "valid_updated_at": "updated_at IS NOT NULL",
        "valid_op": "op IN ('c', 'u', 'd')"
    }
)

@dp.append_flow(
    target="products_cdc_clean",
    name="products_cdc_clean_flow"
)
def products_cdc_clean_flow():
    return (
        spark.readStream.table("products_cdc_bronze")
        .select(
            from_json("payload", payload_schema).alias("parsed")
        )
        .select(
            col("parsed.after.product_id").alias("product_id"),
            col("parsed.after.product_name").alias("product_name"),
            col("parsed.after.product_type").alias("product_type"),
            col("parsed.after.description").alias("description"),
            # Cast the string ZonedTimestamps to PySpark TimestampType
            to_timestamp(col("parsed.after.created_at")).alias("created_at"),
            to_timestamp(col("parsed.after.updated_at")).alias("updated_at"),
            col("parsed.op").alias("op"),
            col("parsed.source.ts_ms").alias("ts_ms")
        )
    )