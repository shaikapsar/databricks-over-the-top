from pyspark import pipelines as dp
from pyspark.sql.functions import *

dp.create_streaming_table(
    name="products_history", comment="Clean, materialized products"
)

dp.create_auto_cdc_flow(
    target="products_history",
    source="products_cdc_clean",
    keys=["product_id"],
    sequence_by=col("ts_ms"),
    ignore_null_updates=False,
    apply_as_deletes=expr("op = 'd'"),
    except_column_list=["op", "ts_ms"],
    stored_as_scd_type="2",
)
