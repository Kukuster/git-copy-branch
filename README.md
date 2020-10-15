## Short Description
I. creates 2 dirs in the current dir:
  - `dirread`
  - `dicreate`

 II. fetches the repo in the `dirread`
 
 III. creates a new repo in the `dircreate`
 
IV. Loops through the commits in the specified branch in `dirread`, starting from the oldest commit; and for each commit it copies everything from `dirread` to `dircreate` except the specified `Exceptions`, and makes a commit in `dircreate` with the message name of the one in `dirread`.
**Thus effectively creates a new repository and copies all commits of a branch but excludes certain files and dirs completely from the tracking history.**

## Dependencies
 - git
 - rsync
 
## Details

<br> Merges are not preserved, only the main 1-d part of the branch is copied, navigating through the first parents starting from the latest commit in the branch.

<br>`dirread` and `dircreate` names, `Exceptions`, repository url, and branch name are to be specified in `config.sh` file.

<br>Also, as for `Exceptions`, higher-level paths work as well. E.g. putting `"core/notes.txt"` will only omit that file, preserving everything else in the `"core"` directory

<br>A considerable chunk of the script is checks: if you have `git` and `rsync` installed, if there's a `config.sh` file in the current dir, if the specified remote repository exists and readable, etc. So that the script is unlikely to make some mess if something went wrong unintentionally.

<br>**This script doesn't push or affect your remote repository in any way. The only effect of this script is local, within the directory where the script is executed.
<br>You can configure `config.sh` file, execute the script with `bash`, and check if the newly created repo works for you.
<br>Output of all key executed git commands is preserved.**

