"""Postgres access for the fast2pg demo."""

import os

from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql:///fast2pg")

pool = ConnectionPool(
    DATABASE_URL,
    min_size=1,
    max_size=10,
    open=False,
    kwargs={"row_factory": dict_row},
)

SCHEMA = """
CREATE TABLE IF NOT EXISTS entries (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


def init_db() -> None:
    """Open the pool and create the table if needed."""
    pool.open(wait=True)
    with pool.connection() as conn:
        conn.execute(SCHEMA)


def close_db() -> None:
    """Close all pooled connections."""
    pool.close()


def add_entry(content: str) -> None:
    """Store a single string."""
    with pool.connection() as conn:
        conn.execute("INSERT INTO entries (content) VALUES (%s)", (content,))


def list_entries(limit: int = 50) -> list[dict]:
    """Return the most recent entries, newest first."""
    with pool.connection() as conn:
        cur = conn.execute(
            "SELECT id, content, created_at FROM entries ORDER BY id DESC LIMIT %s",
            (limit,),
        )
        return cur.fetchall()
