module Agent = {
  let dirName = "__buffer__"
}

module DB = {
  let dirName = "db"
  let metadata = "metadata.db"
  let targets = "targets.db"
}

module Parser = {
  let fileName = "targets-parser.mjs"
}

module Telemetry = {
  let configFileName = "telemetry.config.json"

  let parseConfigArrayLikeProperty = (property: string) => {
    let rootDir = Path.resolve([""])
    let configFilePath = Path.join([rootDir, configFileName])

    let decodedValues =
      configFilePath
      ->Fs.readFileSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->JSON.parseExn
      ->JSON.Decode.object
      ->Option.getExn
      ->Dict.get(property)
      ->Option.getExn
      ->JSON.Decode.array
      ->Option.getExn
      ->Array.map(value =>
        value
        ->JSON.Decode.string
        ->Option.getExn
      )

    decodedValues
  }

  let repositories = parseConfigArrayLikeProperty("repositories")
}
