type database
type statement
type row = Dict.t<JSON.t>

type options = {
  readonly?: bool,
  fileMustExist?: bool,
  timeout?: int,
  verbose?: string => unit,
}

@module("better-sqlite3")
external createDatabase: (string, ~options: options=?) => database = "default"

@send
external prepare: (database, string) => statement = "prepare"

@send
external get: (statement, 'params) => Nullable.t<row> = "get"

@send
external all: (statement, 'params) => array<row> = "all"

@send
external run: (statement, 'params) => unit = "run"

@send
external exec: (database, string) => unit = "exec"

@send
external close: database => unit = "close"
