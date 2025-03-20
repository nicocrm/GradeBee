from appwrite.client import Client
from appwrite.services.databases import Databases
from appwrite.services.storage import Storage
from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

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
