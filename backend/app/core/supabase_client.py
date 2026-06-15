import os
from dotenv import load_dotenv
from supabase import create_client, Client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    # If keys are missing, print warning but don't fail immediately in dev
    import warnings
    warnings.warn("SUPABASE_URL or SUPABASE_SERVICE_KEY is missing from environment variables.")

# Create the Supabase client
supabase: Client = create_client(
    supabase_url=SUPABASE_URL or "https://placeholder.supabase.co",
    supabase_key=SUPABASE_SERVICE_KEY or "placeholder-key"
)
