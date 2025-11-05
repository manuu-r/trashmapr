"""
Centralized configuration management using Pydantic Settings.
All environment variables must be defined in .env file.
"""

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    All settings must be provided in .env file.
    """

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore"
    )

    # Database Configuration
    alloydb_connection_uri: str = Field(...)

    # Google Cloud Authentication
    google_oauth_client_id: str = Field(...)
    google_oauth_client_secret: str = Field(...)
    google_application_credentials: str = Field(...)

    # Google Cloud Services
    gemini_api_key: str = Field(...)
    gcs_bucket_name: str = Field(...)
    gcp_project_id: str = Field(...)
    gcp_region: str = Field(...)

    # Application Configuration
    secret_key: str = Field(..., min_length=32)
    oauth_redirect_uri: str = Field(...)

    # Application Settings
    app_name: str = "TrashMapr API"
    app_version: str = "1.0.0"
    debug: bool = True
    cors_origins: list[str] = ["*"]

    # Database Settings
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_echo: bool = False

    # Validators
    @field_validator("alloydb_connection_uri")
    @classmethod
    def validate_database_uri(cls, v: str) -> str:
        """Validate database URI format."""
        if not v.startswith("postgresql+asyncpg://"):
            raise ValueError(
                "Database URI must start with 'postgresql+asyncpg://' for async support"
            )
        return v

    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        """Validate secret key is not a default/weak value."""
        weak_keys = [
            "your-secret-key",
            "change-this",
            "secret",
            "password",
            "12345",
        ]
        if any(weak in v.lower() for weak in weak_keys):
            raise ValueError(
                "SECRET_KEY appears to be a default/weak value. "
                "Generate a secure key with: openssl rand -hex 32"
            )
        return v

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v):
        """Parse CORS origins from comma-separated string or list."""
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v

    # Helper Properties
    @property
    def database_url(self) -> str:
        """Alias for alloydb_connection_uri."""
        return self.alloydb_connection_uri

    @property
    def is_production(self) -> bool:
        """Check if running in production mode."""
        return not self.debug

    def model_post_init(self, __context) -> None:
        """Post-initialization hook to set GOOGLE_APPLICATION_CREDENTIALS env var."""
        import os

        os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = (
            self.google_application_credentials
        )


# Global Settings Instance
settings = Settings()
