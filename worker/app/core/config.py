"""
Worker configuration management using Pydantic Settings.
Simplified version for the worker service.
"""

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Worker settings loaded from environment variables.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
        env_ignore_empty=True,
    )

    # Database Configuration
    alloydb_connection_uri: str = Field(...)

    # Google Cloud Services
    gemini_api_key: str = Field(...)
    gcs_bucket_name: str = Field(...)
    google_application_credentials: str | None = Field(default=None)

    # Application Settings
    app_name: str = "TrashMapr Worker"
    app_version: str = "1.0.0"
    debug: bool = False

    # Database Settings
    db_pool_size: int = 5
    db_max_overflow: int = 10
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

    # Helper Properties
    @property
    def database_url(self) -> str:
        """Alias for alloydb_connection_uri."""
        return self.alloydb_connection_uri

    def model_post_init(self, __context) -> None:
        """Post-initialization hook to set GOOGLE_APPLICATION_CREDENTIALS env var."""
        import os

        if self.google_application_credentials:
            os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = (
                self.google_application_credentials
            )


# Global Settings Instance
settings = Settings()
