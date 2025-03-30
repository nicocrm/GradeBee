from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.services.storage import Storage
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv(override=True)

def validate_env_vars():
    required_vars = [
        "APPWRITE_ENDPOINT",
        "APPWRITE_PROJECT_ID",
        "APPWRITE_API_KEY",
        "APPWRITE_DATABASE_ID",
        "NOTES_BUCKET_ID",
        "DEFAULT_USER_ID"
    ]
    
    missing_vars = [var for var in required_vars if not os.getenv(var)]
    
    if missing_vars:
        raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

# Validate environment variables before proceeding
validate_env_vars()

client = Client()

(
    client.set_endpoint(os.getenv("APPWRITE_ENDPOINT"))  # Your API Endpoint
    .set_project(os.getenv("APPWRITE_PROJECT_ID"))  # Get project ID from environment
    .set_key(os.getenv("APPWRITE_API_KEY"))  # Your secret API key
)

databases = Databases(client)
storage = Storage(client)
database_id = os.getenv("APPWRITE_DATABASE_ID")
bucket_id = os.getenv("NOTES_BUCKET_ID")
default_user_id = os.getenv("DEFAULT_USER_ID")
