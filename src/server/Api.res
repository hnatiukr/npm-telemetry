let prefix = "/api"

let makeRoute = (pathname: string) => `${prefix}/${pathname}`

type routes = {
  api: string,
  repositories: string,
  repository: string,
}

let routes: routes = {
  api: prefix,
  repositories: makeRoute("repositories"),
  repository: makeRoute("repositories/:repository"),
}
