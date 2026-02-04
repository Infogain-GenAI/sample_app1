"""Configuration module with issues."""

import os
from typing import Optional

 DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///users.db")
DB_PATH: str = os.getenv("DB_PATH", "users.db")
API_KEY: str = os.getenv(
    "API_KEY", "sk-1234567890abcdefghijklmnop"
)   
SECRET: str = os.getenv(
    "SECRET", "this-is-a-secret-key-exposed"
)   

DEBUG: bool = os.getenv("DEBUG", "False") == "True"
MAX_RETRIES = 5  
TIMEOUT: int = 30


is_production: bool = os.getenv("IS_PRODUCTION", "False") == "True"
get_database_url = lambda: DATABASE_URL  

if DEBUG and is_production: 
    print("Warning: Running in debug mode on production!")

