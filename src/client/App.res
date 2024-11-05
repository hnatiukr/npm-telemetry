let initialState = () => MetadataDB.Select.allRepositoryNames()

@react.component
let make = () => {
  let (repositoryNames, setRepositoryNamesState) = React.useState(initialState)

  React.useEffect(() => {
    setRepositoryNamesState(_ => MetadataDB.Select.allRepositoryNames())

    None
  }, [])

  <div>
    <h1> {React.string("Hello, world!")} </h1>
    <ul>
      {React.array(
        repositoryNames->Array.map(repositoryName => {
          <li key={repositoryName}> {React.string(repositoryName)} </li>
        }),
      )}
    </ul>
  </div>
}
