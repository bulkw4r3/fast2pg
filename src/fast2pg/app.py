"""A tiny FastHTML app that stores strings in Postgres."""

from fasthtml.common import *

from . import db

INPUT_ID = "content"


def startup():
    db.init_db()


def shutdown():
    db.close_db()


app, rt = fast_app(
    on_startup=startup,
    on_shutdown=shutdown,
    hdrs=(
        Style("""
            #entries ul { list-style: none; padding: 0; margin: 0; }
            #entries li {
                display: flex; justify-content: space-between; gap: 1rem;
                padding: .5rem 0;
                border-bottom: 1px solid var(--pico-muted-border-color);
            }
            #entries li:last-child { border-bottom: 0; }
            #entries time { white-space: nowrap; opacity: .6; font-size: .8rem; }
        """),
    ),
)


def entries_panel():
    "Render the stored strings."
    entries = db.list_entries()
    if not entries:
        body = P("Nothing stored yet.")
    else:
        body = Ul(
            *[
                Li(
                    Span(entry["content"]),
                    Time(
                        entry["created_at"].strftime("%Y-%m-%d %H:%M:%S"),
                        datetime=entry["created_at"].isoformat(),
                    ),
                )
                for entry in entries
            ]
        )
    return Div(H2("Stored strings"), body, id="entries")


@rt(methods=["POST"])
def add(content: str):
    "Store the submitted string and refresh the list."
    content = content.strip()
    if content:
        db.add_entry(content)
    cleared_input = Input(
        id=INPUT_ID,
        name=INPUT_ID,
        placeholder="Type something…",
        required=True,
        autofocus=True,
        autocomplete="off",
        hx_swap_oob="true",
    )
    return entries_panel(), cleared_input


def entry_form():
    "The one-field form that posts to `add`."
    return Form(
        Label(
            "String",
            Input(
                id=INPUT_ID,
                name=INPUT_ID,
                placeholder="Type something…",
                required=True,
                autofocus=True,
                autocomplete="off",
            ),
        ),
        Button("Store"),
        method="post",
        hx_post=add,
        hx_target="#entries",
        hx_swap="outerHTML",
    )


@rt
def index():
    return Titled(
        "fast2pg",
        P("Enter a string and store it in Postgres."),
        entry_form(),
        entries_panel(),
    )
