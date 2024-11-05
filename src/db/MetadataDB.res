type metadata = {
  repositoryName: string,
  releaseVersion: string,
  gitBranchName: string,
  gitCommitHash: string,
  gitCommitDate: string,
  dependencies: array<(string, string)>,
  envVars: array<string>,
}

if !Fs.existsSync(Path.resolve(["", "db"])) {
  Fs.mkdirSync(Path.resolve(["", "db"]))
}

let db = DB.createDatabase(Path.join([Config.DB.dirName, Config.DB.metadata]))

db->DB.exec(`
    CREATE TABLE IF NOT EXISTS metadata (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      repositoryName TEXT,
      releaseVersion TEXT,
      gitBranchName TEXT,
      gitCommitHash TEXT,
      gitCommitDate TEXT,
      dependencies TEXT,
      envVars TEXT
    )
  `)

module Select = {
  let rec orCreateRepository = repositoryName => {
    let query = "SELECT id FROM metadata WHERE repositoryName = ? ORDER BY id DESC LIMIT 1"
    let stmt = db->DB.prepare(query)
    let row = stmt->DB.get(repositoryName)->Nullable.toOption

    switch row {
    | Some(data) =>
      data
      ->Dict.get("id")
      ->Option.getExn
      ->JSON.Decode.float
      ->Option.getExn
      ->Int.fromFloat
    | None => {
        let query = "INSERT INTO metadata (repositoryName) VALUES (?)"
        let insertStmt = db->DB.prepare(query)

        insertStmt->DB.run(repositoryName)
        orCreateRepository(repositoryName)
      }
    }
  }

  let allRepositoryNames = () => {
    let query = "SELECT DISTINCT repositoryName FROM metadata ORDER BY repositoryName"
    let stmt = db->DB.prepare(query)
    let rows = stmt->DB.all()

    rows->Array.reduce([], (acc, row) => {
      switch row->Dict.get("repositoryName")->Option.flatMap(JSON.Decode.string) {
      | Some(name) => acc->Array.concat([name])
      | None => acc
      }
    })
  }

  let metadataJson = repositoryName => {
    let query = "SELECT * FROM metadata WHERE repositoryName = ? ORDER BY id DESC LIMIT 1"
    let stmt = db->DB.prepare(query)
    let row = stmt->DB.get(repositoryName)->Nullable.toOption

    switch row {
    | Some(data) => Some(data)
    | None => None
    }
  }

  let metadata = repositoryName => {
    let query = "SELECT * FROM metadata WHERE repositoryName = ? ORDER BY id DESC LIMIT 1"
    let stmt = db->DB.prepare(query)
    let row = stmt->DB.get(repositoryName)->Nullable.toOption

    switch row {
    | Some(data) => {
        let getString = key =>
          data
          ->Dict.get(key)
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")

        Some({
          repositoryName: getString("repositoryName"),
          releaseVersion: getString("releaseVersion"),
          gitBranchName: getString("gitBranchName"),
          gitCommitHash: getString("gitCommitHash"),
          gitCommitDate: getString("gitCommitDate"),
          dependencies: data
          ->Dict.get("dependencies")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("[]")
          ->JSON.parseExn
          ->JSON.Decode.array
          ->Option.getExn
          ->Array.map(item => {
            let arr = item->JSON.Decode.array->Option.getExn
            (
              arr[0]->Option.getExn->JSON.Decode.string->Option.getExn,
              arr[1]->Option.getExn->JSON.Decode.string->Option.getExn,
            )
          }),
          envVars: data
          ->Dict.get("envVars")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("[]")
          ->JSON.parseExn
          ->JSON.Decode.array
          ->Option.getExn
          ->Belt.Array.keepMap(JSON.Decode.string),
        })
      }
    | None => None
    }
  }
}

module Insert = {
  let releaseVersion = (repositoryName, newVersion) => {
    let query = "UPDATE metadata SET releaseVersion = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)

    stmt->DB.run((newVersion, id))
  }

  let gitBranchName = (repositoryName, newBranch) => {
    let query = "UPDATE metadata SET gitBranchName = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)

    stmt->DB.run((newBranch, id))
  }

  let gitCommitHash = (repositoryName, newHash) => {
    let query = "UPDATE metadata SET gitCommitHash = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)

    stmt->DB.run((newHash, id))
  }

  let gitCommitDate = (repositoryName, newDate) => {
    let query = "UPDATE metadata SET gitCommitDate = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)

    stmt->DB.run((newDate, id))
  }

  let dependencies = (repositoryName, newDependencies) => {
    let query = "UPDATE metadata SET dependencies = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)
    let dependenciesJson = newDependencies->JSON.stringifyAny->Option.getExn

    stmt->DB.run((dependenciesJson, id))
  }

  let envVars = (repositoryName, newEnvVars) => {
    let query = "UPDATE metadata SET envVars = ? WHERE id = ?"
    let stmt = db->DB.prepare(query)
    let id = Select.orCreateRepository(repositoryName)
    let envVarsJson = newEnvVars->JSON.stringifyAny->Option.getExn

    stmt->DB.run((envVarsJson, id))
  }
}
