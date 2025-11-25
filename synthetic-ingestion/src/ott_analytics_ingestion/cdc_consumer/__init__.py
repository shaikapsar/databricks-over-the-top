import json
import logging
import os
import sys

from confluent_kafka import Consumer, KafkaError, KafkaException
from databricks.sdk import WorkspaceClient
from dotenv import load_dotenv

# Assuming these utilities exist in your project structure
from ott_analytics_ingestion.utils import upload_files, upload_file_landing_zone, VOLUME_DIRECTORY, \
    create_volume_directory_if_not_exist

load_dotenv()

logger = logging.getLogger(__name__)

# Configuration for the consumer
conf = {
    'bootstrap.servers': os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),  # Added default for safety
    'group.id': os.getenv("KAFKA_CONSUMER_GROUP_ID", "OTT-ANALYTICS"),  # Added default for safety
    'auto.offset.reset': os.getenv("KAFKA_CONSUMER_AUTO_OFFSET_RESET", 'earliest'),
    'enable.auto.commit': False
}

BASE_SAVE_DIR = os.getenv("CDC_DIR", "./cdc_data")

landing_zone_directories = []

def process_message(consumer_instance, msg):
    """
    Function to process the consumed message, save the payload to a specific file structure,
    including the message ID in the filename.
    """
    if msg is None:
        return
    if msg.error():
        if msg.error().code() == KafkaError._PARTITION_EOF:
            logger.info(f'%% {msg.topic()} [{msg.partition()}] reached end at offset {msg.offset()}')
        elif msg.error():
            raise KafkaException(msg.error())
    else:
        topic_name = msg.topic()

        # --- EXTRACT MESSAGE ID from headers ---
        message_id = f"offset_{msg.offset()}"


        try:
            # Decode value from bytes to string and parse as JSON
            raw_value = msg.value().decode('utf-8')
            data = json.loads(raw_value)

            logger.info(f"[{topic_name}] Received message ID: {message_id}")

            # --- Extract required attributes from the JSON message structure (Debezium format) ---
            catalog = data['payload']['source']['name']
            schema = data['payload']['source']['schema']
            table = data['payload']['source']['table']
            payload_content = data

            # --- Construct directory path: ./kafka_data/catalog/schema/table/ ---
            save_dir = os.path.join(BASE_SAVE_DIR, catalog, schema, table)
            os.makedirs(save_dir, exist_ok=True)

            # --- Construct file path using the message_id ---
            file_name = f"{catalog}_{schema}_{table}_{message_id}.json"
            file_path = os.path.join(save_dir, file_name)

            landing_zone_dir = VOLUME_DIRECTORY.format(
                catalog=os.getenv("DATABRICKS_CATALOG"),
                schema=os.getenv("DATABRICKS_SCHEMA"),
                volume=os.getenv("DATABRICKS_VOLUME"),
                directory=table)

            if landing_zone_dir not in landing_zone_directories:
                # Ensure the destination volume directory exists in Databricks
                create_volume_directory_if_not_exist(workspace_client=WorkspaceClient(),
                                                     catalog=os.getenv("DATABRICKS_CATALOG"),
                                                     schema=os.getenv("DATABRICKS_SCHEMA"),
                                                     volume=os.getenv("DATABRICKS_VOLUME"),
                                                     directory=table)
                landing_zone_directories.append(landing_zone_dir)

            landing_zone_file = os.path.join(landing_zone_dir, file_name)

            # --- Write the payload content locally to the file ---
            with open(file_path, 'w') as f:
                json.dump(payload_content, f, indent=4)

            logger.info(f"[{topic_name}] Successfully saved payload locally to: {file_path}")

            # Upload the file to the Databricks landing zone/volume
            upload_file_landing_zone(workspace_client=WorkspaceClient(), source_path=file_path,
                                     destination_path=landing_zone_file)

            # Clean up the local file after successful upload
            if os.path.exists(file_path):
                os.remove(file_path)
                logger.debug(f"[{topic_name}] Deleted local file: {file_path}")

            # Commit the offset synchronously after successful processing and file write
            consumer_instance.commit(msg, asynchronous=False)
            logger.info(f"[{topic_name}] Committed offset {msg.offset()} successfully.")

        except json.JSONDecodeError:
            logger.error(f"[{topic_name}] Error decoding JSON from message value. Value: {raw_value[:100]}...",
                         exc_info=True)
        except KeyError as e:
            logger.error(f"[{topic_name}] Missing expected key in message data: {e}", exc_info=True)
        except Exception as e:
            logger.error(
                f"[{topic_name}] Error processing message or saving file: {e}. Offset NOT committed.",
                exc_info=True)


def consume_loop(consumer, topics: list):
    try:
        # Check if basic configuration is present before subscribing
        if not conf.get('bootstrap.servers') or not conf.get('group.id'):
            logger.error("Missing KAFKA_BOOTSTRAP_SERVERS or KAFKA_CONSUMER_GROUP_ID environment variables.")
            sys.exit(1)

        consumer.subscribe(topics)
        logger.info(f"Subscribed to topics: {topics}. Waiting for messages...")

        while True:
            msg = consumer.poll(timeout=1.0)
            if msg is not None:
                process_message(consumer, msg)

    except KeyboardInterrupt:
        sys.stderr.write('%% Aborted by user\\n')
    finally:
        consumer.close()
        logger.info("Consumer closed.")


def ingest_cdc_events():
    kafka_consumer = Consumer(conf)
    # Assumes KAFKA_CONSUMER_TOPICS is a comma-separated string in the .env file
    topics_list = os.getenv("KAFKA_CONSUMER_TOPICS", "").split(",")
    if not topics_list or topics_list == [""]:
        logger.error("KAFKA_CONSUMER_TOPICS environment variable is not set or empty.")
        sys.exit(1)

    consume_loop(kafka_consumer, topics=topics_list)


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    # Environment variables are loaded at the top of the file via load_dotenv()
    ingest_cdc_events()
