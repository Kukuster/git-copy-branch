# This is a template config file!
# Set up your configuration and rename this file to "config.sh"


# BEWARE! This file has potential to inject ANY bash code
# Use conscionsly, as intended


dirread="newrepo_tmp"

dircreate="newrepo"

# ssh or https
remote="git@github.com:Kukuster/kukinterviewer.git"

# branch name
branch="localdev"

#$@ - files and directories to exclude
Exclude=( "devnotes.txt" )

