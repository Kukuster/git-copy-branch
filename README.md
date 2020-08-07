#### short description
I. creates 2 dirs:
  - `dirread`
  - `dicreate`

 II. fetches the repo in the `dirread`
 
 III. creates a new repo in the `dircreate`
 
IV. Loops through the commits in the specified branch in `dirread`, starting from the oldest commit; and for each commit it copies everything from `dirread` to `dircreate` except the specified Exceptions, and makes a commit in `dircreate` with the message name of the one in `dirread`.
**Thus effectively creates a new repository and copies all commits of a branch but excludes certain files and dirs completely from the tracking history.**




<br>
`dirread` and `dircreate` names, Exceptions, repository url and branch name are to be specified in `config.sh` file.


<br>
Also, as for Exceptions, higher-level paths also work, f.e. putting `"core/notes.txt"` would only omit that file, while leaving everything else in the `"core"` directory

