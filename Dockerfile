# syntax=docker/dockerfile:1

FROM python:3.15-slim-trixie

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PGDATA=/var/lib/postgresql/data \
    DATABASE_URL=postgresql:///fast2pg?host=/var/run/postgresql

# Postgres runs inside this same container. tini reaps child processes, gosu
# drops privileges for Postgres and the app.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gosu \
        postgresql \
        postgresql-client \
        tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock README.md ./
COPY src ./src
RUN uv sync --frozen --no-dev \
    && useradd --create-home --uid 1000 app \
    && chown -R app:app /app \
    && install -d -o postgres -g postgres -m 700 "$PGDATA"

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

EXPOSE 5001
VOLUME ["/var/lib/postgresql/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5001/')" || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
