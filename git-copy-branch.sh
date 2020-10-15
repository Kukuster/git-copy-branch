#!/usr/bin/env bash


############################################
#==========================================#
#       PROGRAM HEAD (declarations)        #
#==========================================#
############################################


declare -r programname="git-rebuild-branch"
declare -r version="1.0"
declare -r revision="2020.08.02"
declare -r source="https://github.com/Kukuster/"


#=#=#=#=#= variables =#=#=#=#=#

declare configfile="config.sh"
declare maindir="`pwd`"

# ----- dependencies -----
declare -r git="git"
declare -r rsync="rsync"


# ----- exit codes -----
declare -A ExitCode=()
ExitCode[noconfig]=1
ExitCode[nodependency]=2
ExitCode[wrongconfig]=3
ExitCode[dirIsNotEmpty]=4
ExitCode[dirNoPermissions]=5
ExitCode[cderror]=6
ExitCode[wrongGitData]=7
ExitCode[errorPulling]=8
ExitCode[branchHasNoCommits]=9


# ----- core -----
declare -r remotename="origin"


# ----- formatting -----
#https://misc.flogisoft.com/bash/tip_colors_and_formatting
#https://askubuntu.com/questions/528928/how-to-do-underline-bold-italic-strikethrough-color-background-and-size-i/985386#985386
declare -r format_end='\e[0m'

declare -r b='\e[1m'
declare -r dim='\e[2m'
declare -r b_dim_end='\e[22m'
declare -r b_end='\e[22m'
declare -r dim_end='\e[22m'
declare -r u='\e[4:1m'
declare -r uu='\e[4:2m'
declare -r cu='\e[4:3m'
declare -r u_end='\e[4:0m'
declare -r blink='\e[5m'
declare -r blink_end='\e[25m'

declare -r color_end='\e[39m'
declare -r black='\e[30m'
declare -r red='\e[31m'
declare -r green='\e[32m'
declare -r yellow='\e[33m'
declare -r blue='\e[34m'
declare -r magenta='\e[35m'
declare -r cyan='\e[36m'
declare -r lightgray='\e[37m'
declare -r darkgray='\e[90m'
declare -r lightred='\e[91m'
declare -r lightgreen='\e[92m'
declare -r lightyellow='\e[93m'
declare -r lightblue='\e[94m'
declare -r lightmagenta='\e[95m'
declare -r lightcyan='\e[96m'
declare -r white='\e[97m'

declare -r quote_str="${b}${dim}<<${b_dim_end}"
declare -r unquote_str="${b}${dim}>>${b_dim_end}"

declare -r ERROR="${b}${red}ERROR${color_end}${b_end}"
declare -r WARNING="${b}${yellow}WARNING${color_end}${b_end}"




#=#=#=#=#= functions =#=#=#=#=#

declare Destruct=()
# removes all the garbage before finishing the program
destruct(){
    cd "$maindir"

    for cmd in "${Destruct[@]}"; do
        CMD="$cmd[@]";
        "${!CMD}";
    done;
}
# usage example: {
#   mkdir "$tmpDir"
#   rmTempDir=( rm -rf "$tmpDir" )
#   Destruct+=( rmTempDir )
# }


exit_(){
    #$1 has to be an integer
    destruct
    exit "$1"
}


# ----- formatted output -----

# outputs dim opening quote
quote(){
    echo -e "$quote_str"
}

# outputs dim closing quote
unquote(){
    echo -e "        $unquote_str"
}

# outputs dim vertical ellipsis
ellipsis(){
    echo -e "    ${b}${dim}."
    echo -e "    ."
    echo -e "    .${b_dim_end}"
}

# trims the given output ($1) in terms of lines
trim_output(){
    #$1 - string
    #$2 - max allowed number of lines
    #$3 - number of lines to trim to, if max ($2) is exceeded
    lines=`echo "$1" | wc -l`
    if [ $lines -gt $2 ]; then
        echo -e "$1" | head -n $3
        echo -e "    ${b}${dim}."
        echo -e "    ."
        echo -e "    .${b_dim_end}"
    else
        echo -e "$1"
    fi
}



# ----- reusable -----

# cuts the single leading slash, if it exists, echoes the same string otherwise
cutLeadingSlash(){
    #$1 - string to cut (if there's a leading slash)

    # if the first char is a forward slash
    if [[ "${1:0:1}" == "/" ]]; then
        # cut the first char (equate to substring of the same string starting with character #1)
        echo "${1:1}"
    else
        echo "$1"
    fi

    return 0
}



#checks if a string variable contains any delimiters from defined in $IFS
hasdelimiters(){
    #$1 - string
    #$2 - cutsom $IFS instead of global (optional)

    local IFS="$IFS"
    if [[ ! -z "$2" ]]; then
        IFS="$2"
    fi

    local char=""
    for (( i=0; i<${#IFS}; i++ )); do
        char="${IFS:$i:1}"
        if [[ "$1" == *"$char"* ]]; then
            return 0
        fi
    done

    return 1

#returns 0 if a given string contains delimiters
#returns 1 if it doesn't
}
#example:
#hasdelimiters "$0" && p="\"$0\"" || p="$0"



# checks if a git repository has a specific branch
# depends on:
# variable: "$git" ==  
repositoryHasBranch(){
    #$1 - remote
    #$2 - branch name
    
    local res
    res="`$git ls-remote --heads "$1" "$2" 2>/dev/null`"
    [ $? -eq 128 ] && return 2 || \
             ( [ -z "$res" ] && return 1 || return 0 )

#returns 0 if there's a branch on a remote git repository,
#returns 1 if there's no such branch
#returns 2 if there's no such repository
}


# get absolute from a string
ABSpath(){
    #$1 - a path to resolve

    echo "`cd "$1" 2>/dev/null && pwd`";

    #if path is resolved successfully - echoes the resolved path and returns 0
    #otherwise echoes nothing and returns 1
}



# ----- core -----

# safe change dir
# verifies that the dir has been changed and terminates the program safely if it haven't
cd_(){
    #$1 - path

    local currDir="`pwd`"
    local destination="`ABSpath "$1"`"

    cd "$1" 2>/dev/null 1>&2
    if [[ $? -ne 0 ]] || [[ "`pwd`" != "$destination" ]]; then
        echo -e "$ERROR: unexpected error. Could not change dir to the path '${b}${currDir}/${1}${format_end}'"
        echo -e "terminating script"
        exit_ "${ExitCode[cderror]}"
    fi

}



countCommits(){
    git rev-list HEAD --count 2>/dev/null
}


# echoes a full commit id starting from the oldest commit going through first ancestors
commitN(){
    #$1 - commit number (starting from the first commit)
    declare -i ec=0
    declare -i -r n=$1

    git status 1>/dev/null
    ec=$?
    if [[ $? -eq 128 ]]; then  # when this is "not a git repository"
        return 1
    fi
    # git is a good example of a program for which a nonzero exit code is not necessary an error

    declare -i -r totalcommits=`git rev-list HEAD --count 2>/dev/null`
    if [[ $totalcommits -lt 1 ]] || [[ $n -gt $totalcommits ]]; then
        echo "HEAD"
        return 2
    fi

    declare -i -r n_from_top=$(( totalcommits - n ))
    
    #for --format key (or --pretty, which is an alias) see "git PRETTY FORMATS"
    git log --format=%H --skip=$n_from_top --max-count=1
}


rmAllExcept(){
    #$1 - a dir or file in the current directory that is not to delete
    for fd in {*,.[^.],.??*}; do
        # "if exists" == "if file OR if directory"
        if [[ -e "$fd" ]] && [[ "$fd" != "$1" ]]; then
            rm -rf "$fd"
        fi
    done
}





############################################
#==========================================#
#               PROGRAM BODY               #
#==========================================#
############################################


#=#=#=#=#= checks =#=#=#=#=#


# ----- terminate if git doesn't exist ----- #
if [ ! "`command -v "$git"`" ]; then
    echo -e "$ERROR: Boy, I couldn't find git! \ngit executable has to be available as \"${b}$git${format_end}\""
    exit_ ${ExitCode[nodependency]}
fi

# ----- terminate if rsync doesn't exist ----- #
if [ ! "`command -v "$rsync"`" ]; then
    echo -e "$ERROR: rsync is not installed \"${b}$rsync${format_end}\""
    exit_ ${ExitCode[nodependency]}
fi

# ----- terminate if no config file ----- #
if [[ ! -f "$configfile" ]];then
    echo -e "$ERROR: no config file found at:"

    quote

    hasdelimiters "$configfile" && o="\"$configfile\"" || o="$configfile"
    echo -e "$o"

    unquote

    exit_ "${ExitCode[noconfig]}"
fi


# ----- read (source) config ----- #
. ./"$configfile"


# ----- terminate if config doesn't provide all variables ----- #
declare Missing=()
if [[ -z "$dirread" ]]; then
    Missing+=( "dirread" )
fi
if [[ -z "$dircreate" ]]; then
    Missing+=( "dircreate" )
fi
if [[ -z "$remote" ]]; then
    Missing+=( "remote" )
fi
if [[ -z "$branch" ]]; then
    Missing+=( "branch" )
fi

missingStr=""
for m in "${Missing[@]}"; do
    missingStr+="$m\n"
done

if [[ -n "${Missing[@]}" ]]; then
    echo -e "$ERROR: the following necessary config variables are missing:"
    quote
    echo -e "${b}${missingStr}${format_end}"
    unquote
    exit_ ${ExitCode[wrongconfig]}
fi


# ----- terminate if unable to use $dirread or $dircreate directories ----- #
for dir in "dirread" "dircreate"; do

    if [[ -d "${!dir}" ]]; then

        # read dir contents
        dircontents="`ls -A "${!dir}" 2>/dev/null`"

        # if error reading contents
        if [[ $? -ne 0 ]]; then
            echo -e "$ERROR: cannot use the ${b}${dir}${format_end} directory (${dim}${!dir}${format_end})"
            echo -e "You don't have a permission to read it"
            exit_ ${ExitCode[dirNoPermissions]}
        fi

        # if dir is not empty
        if [ "$dircontents" ]; then
            echo -e "$ERROR: cannot use the ${b}${dir}${format_end} directory (${dim}${!dir}${format_end})"
            echo -e "It's not empty!"
            exit_ ${ExitCode[dirIsNotEmpty]}
        fi

        touch "${!dir}" 2>/dev/null
        # if dir is not writable
        if [[ $? -ne 0 ]]; then
            echo -e "$ERROR: cannot use the ${b}${dir}${format_end} directory (${dim}${!dir}${format_end})"
            echo -e "You don't have a permission to write to it"
            exit_ ${ExitCode[dirNoPermissions]}
        fi

    else 

        output="`mkdir "${!dir}" 2>&1 1>/dev/null`"
        if [[ $? -ne 0 ]]; then
            echo -e "$ERROR: cannot create ${b}${dir}${format_end} directory (${dim}${!dir}${format_end})"
            quote
            echo -e "$output"
            unquote
            exit_ ${ExitCode[dirNoPermissions]}
        fi

    fi

done # for dir in "dirread" "dircreate" 






#=#=#=#=#= git work =#=#=#=#=#



# ----- initialize git repositories ----- #

# init git in dirread

cd_ "$dirread"
"$git" init
"$git" remote add "$remotename" "$remote" 2>/dev/null

emptyDirread=( rm -rf "$dirread" )
Destruct+=( emptyDirread )

repositoryHasBranch "$remotename" "$branch"
ec=$?
if [ $? -ne 0 ]; then

    if [ $? -eq 1 ]; then
        echo -e "$ERROR: branch ${b}${branch}${format_end} doesn't exist on the repository:"
        echo -e "$remotename  $remote"
    elif [ $? -eq 2 ]; then
        echo -e "$ERROR: the repository doesn't exist!"
        echo -e "$remotename  $remote"
    else
        echo -e "$ERROR: unknown error resolving git repository and branch"
        echo -e "$remotename  $remote / $branch"
    fi
    
    exit_ "${ExitCode[wrongGitData]}"

fi

"$git" pull "$remotename" "$branch"
if [ $? -ne 0 ]; then

    echo -e "$ERROR: an error occured while trying to pull"
    echo -e "$remotename  $remote / $branch"
    
    exit_ "${ExitCode[errorPulling]}"

fi


cd_ "$maindir"


# init git in dirread

cd_ "$dircreate"
"$git" init
"$git" checkout -b "$branch"
ec=$?

if [ $ec -ne 0 ]; then
    rm -rf "$dircreate"
    echo -e "$ERROR: error creating a git branch '${b}${branch}${format_end}'"
    exit_ "${ExitCode[wrongGitData]}"
fi


cd_ "$maindir"


# ----- form copying command ----- #

copyCMD=( "$rsync" -avq --exclude='.git' )
for excl in "${Exclude[@]}"; do
    if [ -n "$excl" ]; then        
        excl="${excl//\"/\\\"}" # escapes double quotes
        copyCMD+=( "--exclude=$excl" )
    fi
done

copyCMD+=( "$maindir/$dirread/" "$maindir/$dircreate" )

#usage: "${copyCMD[@]}"



# ----- loop through branch ----- #

cd_ "$dirread"
declare -i -r totalCommits=`countCommits`
if [[ -z $totalCommits ]] || [[ ! $totalCommits -gt 0 ]]; then
    echo -e "$ERROR: unable to access commits in the branch"
    echo -e "$remotename  $remote / $branch"
    exit_ "${ExitCode[branchHasNoCommits]}"
fi

cd_ "$maindir"

for (( i=1; i<=$totalCommits; i++ )); do
    # checkout ith commit (starting from the oldest)
    cd_ "$dirread"
    "$git" checkout "$branch" 2>/dev/null 1>&2
    icommit="`commitN "$i"`"
    imessage="`git log --format=%B -n 1 "$icommit"`"
    "$git" checkout "$icommit" 2>/dev/null
    cd_ "$maindir"


    # make new commit in dircreate
    cd_ "$dircreate"
    rmAllExcept .git
    "${copyCMD[@]}"   # copy all files from dirread to dircreate (with exceptions)
    "$git" add -A && "$git" commit -m "$imessage"
    cd_ "$maindir"

done






exit_ 0


