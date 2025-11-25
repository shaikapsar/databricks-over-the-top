import logging
import os
import uuid

import psycopg2
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


def insert_products_batch(product_list):
    # Database connection parameters
    conn_params = {
        'host': os.getenv("DB_HOST"),
        'port': os.getenv("DB_PORT"),
        'dbname': os.getenv("DB_NAME"),
        'user': os.getenv("DB_USERNAME"),
        'password': os.getenv("DB_PASSWORD")
    }
    conn = None     ,
    try:
        # Establish connection using a context manager
        with psycopg2.connect(**conn_params) as conn:
            # Create a cursor object
            with conn.cursor() as cur:
                # SQL INSERT statement with %s placeholders
                insert_query = """
                INSERT INTO product (product_id, product_name, product_type)
                VALUES (%s, %s, %s);
                """
                # Execute the query
                cur.executemany(insert_query, product_list)

            # Commit the transaction (done automatically when exiting the with conn: block)
            # If not using a context manager, you'd call conn.commit() here
        logger.info(f"Successfully inserted {len(product_list)} rows.")

    except (Exception, psycopg2.DatabaseError) as error:
        logger.error(f"Error: {error}")
        if conn:
            conn.rollback()  # Roll back the transaction if an error occurs

def simulate_product_data_ingestion():
    logger.debug("Simulating product data ingestion...")
    products = list()
    for i in range(1, 100):
        for product_type in ['Linear', 'SVOD', 'TVOD']:
            products.append((str(uuid.uuid4()), f"Product {uuid.uuid4()}{i} {product_type}", product_type))
    insert_products_batch(products)

if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    load_dotenv()
    simulate_product_data_ingestion()
