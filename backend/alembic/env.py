"""
alembic/env.py — Project Chozha
Reads DATABASE_URL from the environment so the same migration scripts work
with both SQLite (dev/default) and Postgres (production) without code changes.
"""

import os
import sys
from logging.config import fileConfig

from alembic import context
from sqlalchemy import engine_from_config, pool

# Make application modules importable from /app (the working dir inside Docker)
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models import Base  # noqa: E402

# ── Alembic config object ────────────────────────────────────────────────────
config = context.config

# Override sqlalchemy.url from the environment — works for SQLite and Postgres.
database_url = os.environ.get("DATABASE_URL", "sqlite:////storage/db/chozha.db")
config.set_main_option("sqlalchemy.url", database_url)

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Autogenerate support — point at the ORM metadata
target_metadata = Base.metadata


# ── Migration runners ────────────────────────────────────────────────────────

def run_migrations_offline() -> None:
    """Run without a live DB connection (generates SQL script only)."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """Run against a live DB connection (normal usage)."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()