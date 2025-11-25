import logging
import os

from databricks.sdk import WorkspaceClient
from databricks.sdk.service.catalog import VolumeType
from databricks.sql import connect
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)

VOLUME_DIRECTORY = "/Volumes/{catalog}/{schema}/{volume}/{directory}"


def create_catalog_schema_if_not_exists(catalog: str, schema: str):
    """
    Creates a Databricks catalog and schema if they do not exist,
    using an external Python client and the databricks-sql-connector,
    with logging added.
    
    Assumes connection details (hostname, http_path, and authentication)
    are available via environment variables.
    """
    try:
        logger.info(f"Attempting to connect to Databricks workspace.")
        # The sql.connect() function reads environment variables automatically
        with connect(
                server_hostname=os.getenv("DATABRICKS_HOST"),
                http_path=os.getenv("DATABRICKS_HTTP_PATH"),
                access_token=os.getenv("DATABRICKS_TOKEN")
        ) as connection:
            logger.info("Connection successful. Obtaining cursor.")
            with connection.cursor() as cursor:
                # 1. Create the catalog if it does not exist
                sql_create_catalog = f"CREATE CATALOG IF NOT EXISTS {catalog}"
                logger.info(f"Executing DDL: {sql_create_catalog}")
                cursor.execute(sql_create_catalog)
                logger.info(f"Catalog '{catalog}' ensured to exist.")

                # 2. Set the context to the new/existing catalog
                sql_use_catalog = f"USE CATALOG {catalog}"
                logger.info(f"Executing DDL: {sql_use_catalog}")
                cursor.execute(sql_use_catalog)
                logger.info(f"Switched to catalog '{catalog}'.")

                # 3. Create the schema (database) if it does not exist within that catalog
                sql_create_schema = f"CREATE SCHEMA IF NOT EXISTS {schema}"
                logger.info(f"Executing DDL: {sql_create_schema}")
                cursor.execute(sql_create_schema)
                logger.info(f"Schema '{catalog}.{schema}' is ready.")

                # Optional: Verify the current context with logging
                cursor.execute("SELECT current_catalog(), current_schema()")
                current_context = cursor.fetchone()
                logger.info(f"Verification: Current catalog and schema: {current_context}")

    except Exception as e:
        logger.error(f"An error occurred during connection or DDL execution: {e}")
        raise e


def create_volume_if_not_exist(workspace_client: WorkspaceClient, catalog: str, schema: str, volume: str):
    create_catalog_schema_if_not_exists(catalog=catalog, schema=schema)
    for v in workspace_client.volumes.list(catalog_name=catalog, schema_name=schema):
        logger.info(f"Existing volume: {v.name}")

    if not any(v.name == volume for v in workspace_client.volumes.list(catalog_name=catalog, schema_name=schema)):
        logger.info(f"Creating volume '{volume}' in {catalog}.{schema}...")
        workspace_client.volumes.create(catalog_name=catalog, schema_name=schema, name=volume,
                                        volume_type=VolumeType.MANAGED)
    else:
        logger.info(f"Volume '{volume}' already exists in {catalog}.{schema}.")


def create_volume_directory_if_not_exist(workspace_client: WorkspaceClient, catalog: str, schema: str, volume: str,
                                         directory):
    create_volume_if_not_exist(workspace_client, catalog=catalog, schema=schema, volume=volume)
    full_directory_path = VOLUME_DIRECTORY.format(catalog=catalog, schema=schema, volume=volume, directory=directory)
    workspace_client.files.create_directory(full_directory_path)
    logger.info(f"Volume directory {full_directory_path} created.")


def upload_files(workspace_client: WorkspaceClient, catalog: str, schema: str, volume: str, directory, source_path):
    full_directory_path = VOLUME_DIRECTORY.format(catalog=catalog, schema=schema, volume=volume, directory=directory)
    workspace_client.files.upload_from(file_path=full_directory_path, source_path=source_path)

def upload_file_landing_zone(workspace_client: WorkspaceClient, source_path: str, destination_path: str):
    workspace_client.files.upload_from(file_path=destination_path, source_path=source_path)


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    load_dotenv()
    # create_volume_directory_if_not_exist(workspace_client=WorkspaceClient(), catalog="ott", schema="analytics",
    #                                     volume="landing_zone", directory="raw_data")
