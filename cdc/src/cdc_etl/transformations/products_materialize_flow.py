from pyspark import pipelines as dp
from pyspark.sql.functions import *

dp.create_streaming_table(name="products_history", comment="Clean, materialized products")

dp.create_auto_cdc_flow(
  target="products_history",  # The customer table being materialized
  source="products_cdc_clean",  # the incoming CDC
  keys=["product_id"],  # what we'll be using to match the rows to upsert
  sequence_by=col("ts_ms"),  # de-duplicate by operation date, getting the most recent value
  ignore_null_updates=False,
  apply_as_deletes=expr("op = 'd'"),  # DELETE condition
  except_column_list=["op", "ts_ms"],
  stored_as_scd_type="2",
)