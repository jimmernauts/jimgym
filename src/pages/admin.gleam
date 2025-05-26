import common
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/attribute.{class, href, id}
import lustre/element.{type Element}
import lustre/element/html.{a, article, div, h1, p, section, td, text, tr}
import rada/date
import sqlite_client
import wisp.{type Request}

pub fn admin(_req: Request) -> List(Element(a)) {
  [
    h1([], [text("Data from SQLite")]),
    section([], [
      article([], [text(sqlite_client.get_all_sessions() |> string.inspect)]),
    ]),
  ]
}
