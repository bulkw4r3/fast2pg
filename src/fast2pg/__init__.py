"""fast2pg: a tiny FastHTML app storing strings in Postgres."""


def main() -> None:
    from fasthtml.common import serve

    serve(appname="fast2pg.app", app="app")
