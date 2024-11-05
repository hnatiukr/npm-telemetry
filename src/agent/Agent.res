/*
  declaration of types
*/

type pointer = {
  repositoryUrl: string,
  bufferDirPath: string,
  repositoryName: string,
  skip: bool,
}

/*
  helpers and utility functions
*/

let makePointer = (repositoryUrl: string) => {
  let skip = ref(false)

  let optionRepositoryName = RegExp.fromString("\/([^\/]+)\.git$")->RegExp.exec(repositoryUrl)

  if optionRepositoryName->Option.isNone {
    Error.panic(`Can't recognize repository name by provided repository URL: ${repositoryUrl}`)
  }

  let repositoryName =
    optionRepositoryName
    ->Option.getExn
    ->RegExp.Result.fullMatch

  let bufferDirPath = Path.resolve(["", Config.Agent.dirName, repositoryName])

  try {
    let lastOriginCommitHash =
      `git ls-remote ${repositoryUrl} HEAD`
      ->ChildProcess.execSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->String.trim
      ->String.split("\t")
      ->Array.get(0)
      ->Option.getExn

    let optionMetadata = MetadataDB.Select.metadata(repositoryName)

    if optionMetadata->Option.isSome {
      let metadata = optionMetadata->Option.getExn

      if metadata.gitCommitHash === lastOriginCommitHash {
        skip := true

        Js.Console.log(`[ok] ${repositoryName} / skiped`)
      }
    }
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] cleanBuffer`)
      Js.Console.error(exn)
    }
  }

  let pointer = {
    repositoryName,
    repositoryUrl,
    bufferDirPath,
    skip: skip.contents,
  }

  pointer
}

let cleanBuffer = () => {
  try {
    let bufferDirPath = Path.resolve(["", Config.Agent.dirName])

    if Fs.existsSync(bufferDirPath) {
      let cmd = `rm -rf ${bufferDirPath}`
      let _ = cmd->ChildProcess.execSync

      Js.Console.error(`[ok] agent / cleanBuffer`)
    }
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] agent / cleanBuffer`)
      Js.Console.error(exn)
    }
  }
}

let collectPackageJsonPaths = (bufferDirPath: string) => {
  let foundPaths: array<string> = []
  let stack = [bufferDirPath]

  while Array.length(stack) > 0 {
    switch Array.pop(stack) {
    | Some(dirPath) =>
      dirPath
      ->Fs.readdirSync
      ->Array.forEach(node => {
        let path = Path.join([dirPath, node])
        let stats = Fs.lstatSync(#String(path))

        if Fs.Stats.isDirectory(stats) {
          stack->Array.push(path)
        } else if node === "package.json" {
          foundPaths->Array.push(path)
        }
      })
    | None => ()
    }
  }

  foundPaths
}

let cloneRepository = (pointer: pointer) => {
  try {
    let cmd = `git clone --depth 1 --quiet ${pointer.repositoryUrl} ${pointer.bufferDirPath}`
    let _ = cmd->ChildProcess.execSync

    Js.Console.log(`[ok] ${pointer.repositoryName} / cloneRepository`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / cloneRepository`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let applyIf = (pointer: pointer, parser: pointer => pointer) => {
  if !pointer.skip {
    parser(pointer)
  } else {
    pointer
  }
}

/*
  data parsers
*/

let parseReleaseVersion = (pointer: pointer) => {
  let releaseVersion = ref("")
  let releaseFilePath = Path.join([pointer.bufferDirPath, "RELEASE"])

  try {
    if Fs.existsSync(releaseFilePath) {
      releaseVersion :=
        releaseFilePath
        ->Fs.readFileSync
        ->Buffer.toStringWithEncoding(StringEncoding.utf8)
        ->String.replace("version=", "")
        ->String.trim
    } else {
      let packageJsonPath = Path.join([pointer.bufferDirPath, "package.json"])

      if Fs.existsSync(packageJsonPath) {
        let packageJsonString =
          packageJsonPath
          ->Fs.readFileSync
          ->Buffer.toStringWithEncoding(StringEncoding.utf8)

        let decodedPackageJson =
          packageJsonString
          ->JSON.parseExn
          ->JSON.Decode.object
          ->Option.getExn

        releaseVersion :=
          decodedPackageJson
          ->Dict.get("version")
          ->Option.getExn
          ->JSON.Decode.string
          ->Option.getExn
          ->String.trim
      }
    }

    if String.length(releaseVersion.contents) > 0 {
      MetadataDB.Insert.releaseVersion(pointer.repositoryName, releaseVersion.contents)
    }

    Js.Console.log(`[ok] ${pointer.repositoryName} / parseReleaseVersion`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / parseReleaseVersion`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let parseEnvVars = (pointer: pointer) => {
  let envVarsFilePath = Path.join([pointer.bufferDirPath, "env-vars"])

  if Fs.existsSync(envVarsFilePath) {
    try {
      let envVars =
        envVarsFilePath
        ->Fs.readFileSync
        ->Buffer.toStringWithEncoding(StringEncoding.utf8)
        ->String.trim
        ->String.split("\n")
        ->Array.map(keyValue =>
          keyValue
          ->String.split("=")
          ->Array.get(0)
          ->Belt.Option.getUnsafe
        )

      if Array.length(envVars) > 0 {
        MetadataDB.Insert.envVars(pointer.repositoryName, envVars)
      }
    } catch {
    | Js.Exn.Error(exn) => {
        Js.Console.error(`[error] ${pointer.repositoryName} / parseEnvVars`)
        Js.Console.error(exn)
      }
    }
  }

  pointer
}

let parseGitBranchName = (pointer: pointer) => {
  try {
    let stdout =
      `git -C ${pointer.bufferDirPath} symbolic-ref --short HEAD`
      ->ChildProcess.execSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->String.trim

    if String.length(stdout) > 0 {
      MetadataDB.Insert.gitBranchName(pointer.repositoryName, stdout)
    }

    Js.Console.log(`[ok] ${pointer.repositoryName} / parseGitBranchName`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / parseGitBranchName`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let parseGitCommitHash = (pointer: pointer) => {
  try {
    let stdout =
      `git -C ${pointer.bufferDirPath} rev-parse HEAD`
      ->ChildProcess.execSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->String.trim

    if String.length(stdout) > 0 {
      MetadataDB.Insert.gitCommitHash(pointer.repositoryName, stdout)
    }

    Js.Console.log(`[ok] ${pointer.repositoryName} / parseGitCommitHash`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / parseGitCommitHash`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let parseGitCommitDate = (pointer: pointer) => {
  try {
    let stdout =
      `git -C ${pointer.bufferDirPath} show -s --format=%cd`
      ->ChildProcess.execSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->String.trim

    if String.length(stdout) > 0 {
      MetadataDB.Insert.gitCommitDate(pointer.repositoryName, stdout)
    }

    Js.Console.log(`[ok] ${pointer.repositoryName} / parseGitCommitDate`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / parseGitCommitDate`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let parseDependencies = (pointer: pointer) => {
  try {
    let dependencies = Dict.make()

    pointer.bufferDirPath
    ->collectPackageJsonPaths
    ->Array.forEach(path => {
      let packageJsonString =
        Fs.readFileSync(path)
        ->Buffer.toStringWithEncoding(StringEncoding.utf8)
        ->String.trim

      let decodedPackageJson =
        packageJsonString
        ->JSON.parseExn
        ->JSON.Decode.object
        ->Option.getExn

      let decodedDependecies =
        decodedPackageJson
        ->Dict.get("dependencies")
        ->Option.getExn
        ->JSON.Decode.object
        ->Option.getExn

      decodedDependecies->Dict.forEachWithKey((key, packageName) => {
        let packageVersion = key->JSON.Decode.string->Option.getExn

        dependencies->Dict.set(packageName, packageVersion)
      })
    })

    let dependencies = dependencies->Dict.toArray

    if dependencies->Array.length > 0 {
      MetadataDB.Insert.dependencies(pointer.repositoryName, dependencies)
    }

    Js.Console.log(`[ok] ${pointer.repositoryName} / parseDependencies`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] ${pointer.repositoryName} / parseDependencies`)
      Js.Console.error(exn)
    }
  }

  pointer
}

let parseTargets = (pointer: pointer) => {
  try {
    let _ =
      `node ${Path.resolve(["", "src", "agent", Config.Parser.fileName])}`
      ->ChildProcess.execSync
      ->Buffer.toStringWithEncoding(StringEncoding.utf8)
      ->String.trim

    Js.Console.log(`[ok] agent / parseTargets`)
  } catch {
  | Js.Exn.Error(exn) => {
      Js.Console.error(`[error] agent / parseTargets`)
      Js.Console.error(exn)
    }
  }

  pointer
}

/*
  main
*/

let main = async () => {
  Js.Console.log(`[ok] agent / start of data collection`)

  let _ =
    Config.Telemetry.repositories
    ->Array.map(repositoryUrl =>
      makePointer(repositoryUrl)
      ->applyIf(cloneRepository)
      ->applyIf(parseReleaseVersion)
      ->applyIf(parseEnvVars)
      ->applyIf(parseGitBranchName)
      ->applyIf(parseGitCommitHash)
      ->applyIf(parseGitCommitDate)
      ->applyIf(parseDependencies)
    )
    ->Array.map(pointer => applyIf(pointer, parseTargets))

  cleanBuffer()

  Js.Console.log(`[ok] agent / data have been collected`)
}

main()->ignore

/*
  DB debug
*/

MetadataDB.Select.allRepositoryNames()->Array.forEach(repositoryName => {
  switch MetadataDB.Select.metadata(repositoryName) {
  | Some(metadata) => {
      Js.Console.log(`Latest metadata for ${repositoryName}:`)
      Js.Console.log(`Release Version: ${metadata.releaseVersion}`)
      Js.Console.log(`Git Branch: ${metadata.gitBranchName}`)
      Js.Console.log(`Git Commit Hash: ${metadata.gitCommitHash}`)
      Js.Console.log(`Git Commit Date: ${metadata.gitCommitDate}`)
      Js.Console.log("Dependencies:")
      metadata.dependencies->Array.forEach(((name, version)) => {
        Js.Console.log(`  ${name}: ${version}`)
      })
      Js.Console.log("Environment Variables:")
      metadata.envVars->Array.forEach(envVar => {
        Js.Console.log(`  ${envVar}`)
      })
      Js.Console.log("")
    }
  | None => Js.Console.log(`No metadata found for ${repositoryName}`)
  }

  let packageNames = TargetsDB.Select.packageNames(repositoryName)
  Js.Console.log(`Targets for ${repositoryName}:`)

  packageNames->Array.forEach(packageName => {
    Js.Console.log(`  Package: ${packageName}`)

    let moduleNames = TargetsDB.Select.moduleNames(packageName)
    moduleNames->Array.forEach(
      moduleName => {
        Js.Console.log(`    Module: ${moduleName}`)

        let paths = TargetsDB.Select.paths(moduleName)
        paths->Array.forEach(
          path => {
            Js.Console.log(`      Used in: ${path}`)
          },
        )
      },
    )
  })

  Js.Console.log("")
})
