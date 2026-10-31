# AGENTS.md

## Project

`fast2pg` is a minimal [FastHTML](https://www.fastht.ml/) demo: one input field
stores a string in Postgres and shows the stored strings below it. Updates use
HTMX partial swaps.

## Stack

- Python 3.15, managed with `uv`
- FastHTML (`python-fasthtml`) with its default Pico CSS
- Postgres via `psycopg` 3 connection pool (`psycopg_pool`)
- Docker: app and Postgres run in the **same** container

## Layout

- `src/fast2pg/app.py` — FastHTML app, routes, HTML components, startup hooks
- `src/fast2pg/db.py` — connection pool, schema creation, insert/list queries
- `src/fast2pg/__init__.py` — `main()` entry point, calls `serve()`
- `src/fast2pg/__main__.py` — allows `python -m fast2pg`
- `Dockerfile` — Python 3.15 + Postgres + app
- `docker/entrypoint.sh` — initializes Postgres, creates role/database, runs app
- `compose.yaml` — single service, persistent `pgdata` volume, port 5001
- `docs/llms-ctx.txt` — FastHTML/HTMX reference material

## Commands

```bash
uv sync                      # install dependencies
createdb fast2pg             # create local database (once)
uv run fast2pg               # run locally on :5001
uv run python -m fast2pg     # alternative local run
uv run ruff check src        # lint
uv run ruff format --check src
docker compose up --build    # run app + Postgres in Docker
docker compose down -v       # stop and delete Postgres data
```

## Configuration

| Variable       | Default                 | Notes                                         |
| -------------- | ----------------------- | --------------------------------------------- |
| `DATABASE_URL` | `postgresql:///fast2pg` | Docker sets `postgresql:///fast2pg?host=/var/run/postgresql` |
| `PORT`         | `5001`                  | App port                                      |

The `entries` table is created on startup by `db.init_db()`, which is wired via
`fast_app(on_startup=..., on_shutdown=...)`.

## App behavior

- `GET /` renders the form and the list of the 50 newest entries.
- `POST /add` is the only method accepted for `/add`. It trims the input,
  inserts it, and returns `entries_panel()` plus a cleared input marked with
  `hx-swap-oob="true"`.
- The form posts with `hx_post` to `/add`, targets `#entries`, and swaps
  `outerHTML`.
- The `#entries` panel and input are plain FastHTML components; keep the
  `id="entries"` / `id="content"` contract intact.

## Docker details

- One container runs Postgres and the app; Postgres is not exposed outside it.
- Postgres data lives in `/var/lib/postgresql/data` (the `pgdata` volume).
- The entrypoint runs as root, uses `gosu` to run Postgres as `postgres` and
  the app as `app`, and `tini` reaps processes.
- On first start it runs `initdb`, then creates role `app` and database
  `fast2pg`. On later starts it reuses the volume.
- `SIGTERM` stops the app and then Postgres cleanly.
- The app is started directly with `.venv/bin/uvicorn` (no reload) rather than
  the `fast2pg` console script.

## Gotchas

- FastHTML's `lifespan` parameter expects an async generator, not an
  `asynccontextmanager`. Use `on_startup` / `on_shutdown` here.
- `serve()` needs `appname="fast2pg.app"` because the app lives in a submodule
  of the package, not in `__main__`.
- FastHTML writes `.sesskey` to the working directory on first run; it is
  gitignored and the app user must be able to write to `/app`.
- Test with `TestClient` as a context manager so startup hooks run:

```python
with TestClient(app) as client:
    ...
```

Tests require a reachable Postgres database.
