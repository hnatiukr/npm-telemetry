let app = Express.express()

app->Express.use(Express.jsonMiddleware())

app->Express.get("/api", (_req, res) => {
  let json = {
    "api": Api.routes.api,
    "repositories": Api.routes.repositories,
    "repository": Api.routes.repository,
  }

  res
  ->Express.status(200)
  ->Express.json(json)
  ->ignore
})

app->Express.get("/api/repositories", (_req, res) => {
  let jsonRepositoryNames =
    MetadataDB.Select.allRepositoryNames()
    ->Array.map(repositoryName => repositoryName->JSON.Encode.string)
    ->JSON.Encode.array

  res
  ->Express.status(200)
  ->Express.json(jsonRepositoryNames)
  ->ignore
})

app->Express.get("/api/repositories/:repository", (req, res) => {
  let optionRepositoryName = req->Express.param("repository")

  if optionRepositoryName->Option.isNone {
    res
    ->Express.status(400)
    ->Express.json({"error": "Param with repository name invalid or didn't provided"})
    ->ignore
  }

  res
  ->Express.status(200)
  ->Express.json(
    optionRepositoryName
    ->Option.getExn
    ->MetadataDB.Select.metadataJson,
  )
  ->ignore
})

app->Express.get("/api/packages", (_req, res) => {
  res
  ->Express.status(200)
  ->Express.json({"1": 1})
  ->ignore
})

app->Express.get("/", (_req, res) => {
  let decodedPackageJson =
    Fs.readFileSync(Path.resolve(["", "package.json"]))
    ->Buffer.toStringWithEncoding(StringEncoding.utf8)
    ->JSON.parseExn
    ->JSON.Decode.object
    ->Option.getExn

  let packageName =
    decodedPackageJson
    ->Dict.get("name")
    ->Option.getExn
    ->JSON.Decode.string
    ->Option.getExn

  let packageVersion =
    decodedPackageJson
    ->Dict.get("version")
    ->Option.getExn
    ->JSON.Decode.string
    ->Option.getExn

  res
  ->Express.status(200)
  ->Express.json({"name": packageName, "version": packageVersion})
  ->ignore
})

app->Express.useWithError((err, _req, res, _next) => {
  Js.Console.error(err)

  let _ = res->Express.status(500)->Express.endWithData("An error occured")
})

let port = switch Process.process->Process.env->Js.Dict.get("PORT") {
| Some(p) => int_of_string(p)
| None => 9001
}

let _ = app->Express.listenWithCallback(port, _ => {
  Js.Console.log(`Listening on http://localhost:${port->Belt.Int.toString}`)
})
