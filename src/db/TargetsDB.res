type target = {
  repositoryName: string,
  packageName: string,
  moduleName: string,
  path: string,
}

if !Fs.existsSync(Path.resolve(["", "db"])) {
  Fs.mkdirSync(Path.resolve(["", "db"]))
}

let db = DB.createDatabase(Path.join([Config.DB.dirName, Config.DB.targets]))

try {
  db->DB.exec(`
    CREATE TABLE IF NOT EXISTS targets (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      repositoryName TEXT,
      packageName TEXT,
      moduleName TEXT,
      path TEXT
    );
  `)
} catch {
| Js.Exn.Error(e) =>
  switch Js.Exn.message(e) {
  | Some(msg) => Js.log("Error creating table: " ++ msg)
  | None => Js.log("An unknown error occurred")
  }
}

module Select = {
  let rec orCreateTarget = (repositoryName, packageName, moduleName, path) => {
    let query = "SELECT id FROM targets WHERE repositoryName = ? AND packageName = ? AND moduleName = ? AND path = ? LIMIT 1"
    let stmt = db->DB.prepare(query)
    let row =
      stmt
      ->DB.get((repositoryName, packageName, moduleName, path))
      ->Nullable.toOption

    switch row {
    | Some(data) =>
      data
      ->Dict.get("id")
      ->Option.getExn
      ->JSON.Decode.float
      ->Option.getExn
      ->Int.fromFloat
    | None => {
        let query = "INSERT INTO targets (repositoryName, packageName, moduleName, path) VALUES (?, ?, ?, ?)"
        let insertStmt = db->DB.prepare(query)

        insertStmt->DB.run((repositoryName, packageName, moduleName, path))
        orCreateTarget(repositoryName, packageName, moduleName, path)
      }
    }
  }

  let packageNames = repositoryName => {
    let query = "SELECT DISTINCT packageName FROM targets WHERE repositoryName = ?"
    let stmt = db->DB.prepare(query)
    let rows = stmt->DB.all(repositoryName)

    rows->Array.map(row =>
      row
      ->Dict.get("packageName")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")
    )
  }

  let packageNamesJson = repositoryName => {
    let query = "SELECT DISTINCT packageName FROM targets WHERE repositoryName = ?"
    let stmt = db->DB.prepare(query)
    let rows = stmt->DB.all(repositoryName)

    rows->Array.map(row =>
      row
      ->Dict.get("packageName")
      ->Option.getOr(JSON.Encode.string(""))
    )
  }

  let moduleNames = packageName => {
    let query = "SELECT DISTINCT moduleName FROM targets WHERE packageName = ?"
    let stmt = db->DB.prepare(query)
    let rows = stmt->DB.all(packageName)

    rows->Array.map(row =>
      row
      ->Dict.get("moduleName")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")
    )
  }

  let paths = moduleName => {
    let query = "SELECT path FROM targets WHERE moduleName = ?"
    let stmt = db->DB.prepare(query)
    let rows = stmt->DB.all(moduleName)

    rows->Array.map(row =>
      row
      ->Dict.get("path")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("")
    )
  }
}

module Insert = {
  let target = (repositoryName, packageName, moduleName, path) => {
    let query = "UPDATE targets SET repositoryName = ?, packageName = ?, moduleName = ?, path = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateTarget(repositoryName, packageName, moduleName, path)

    stmt->DB.run((repositoryName, packageName, moduleName, path, id))
  }
}
