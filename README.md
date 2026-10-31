# fast2pg

A minimal [FastHTML](https://www.fastht.ml/) app with a single input field. Each
submitted string is stored in Postgres and shown in a list, updated with HTMX.

## Requirements

- Python 3.15+
- [uv](https://docs.astral.sh/uv/)
- PostgreSQL running locally

## Setup

Create the database (once):

```bash
createdb fast2pg
```

Install dependencies:

```bash
uv sync
```

## Run

```bash
uv run fast2pg
```

or:

```bash
uv run python -m fast2pg
```

Open <http://localhost:5001>.

## Run with Docker

The image contains both the app and Postgres:

```bash
docker compose up --build
```

Open <http://localhost:5001>. Postgres data is stored in the `pgdata` volume.
To start over with an empty database:

```bash
docker compose down -v
```

On first start the container initializes Postgres, creates the `app` role and
the `fast2pg` database, then starts the app on port 5001. Postgres itself is
only reachable inside the container.

> This single-container setup keeps the demo simple. For production, use a
> separate managed Postgres service instead.

## Configuration

| Variable       | Default                 | Description                |
| -------------- | ----------------------- | -------------------------- |
| `DATABASE_URL` | `postgresql:///fast2pg` | Postgres connection string |
| `PORT`         | `5001`                  | HTTP port                  |

Example with a TCP connection:

```bash
DATABASE_URL=postgresql://user:password@localhost:5432/fast2pg uv run fast2pg
```

The `entries` table is created automatically on startup.

Inside the Docker image, `DATABASE_URL` is set to
`postgresql:///fast2pg?host=/var/run/postgresql`, so the app talks to the
Postgres instance in the same container over a Unix socket.

## Layout

- `src/fast2pg/app.py` — FastHTML app, routes, and HTML components
- `src/fast2pg/db.py` — Postgres connection pool and queries
- `src/fast2pg/__init__.py` — console entry point
- `Dockerfile` — app + Postgres image
- `docker/entrypoint.sh` — initializes Postgres, creates the database, starts the app
- `compose.yaml` — runs the container with a persistent Postgres volume
