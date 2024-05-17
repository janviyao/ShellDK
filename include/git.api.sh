#!/bin/bash
: ${INCLUDED_GIT:=1}

alias mygit='loop2success git'
alias gclone='mygit clone --recurse-submodules'
alias gadd='git add -A'
alias gpull='mygit pull'
alias gcommit='function git_commit { git commit -s -m "$@"; return $?; }; git_commit'
alias gamend='function git_amend { git commit --amend -s -m "$@"; return $?; }; git_amend'
alias gall='function git_all { git add -A; git commit -s -m "$@"; git push origin $(git symbolic-ref --short -q HEAD); return $?; }; git_all'
alias ggrep='function git_grep { git log --grep="$@" --oneline; return $?; }; git_grep'

function gpush
{
    local cur_branch=$(git symbolic-ref --short -q HEAD)

    #git fetch &> /dev/null
    #local diff_str=$(git diff --stat origin/${cur_branch})

    git push origin ${cur_branch}
    local retcode=$?
    if [ ${retcode} -ne 0 ];then
        local xselect=$(input_prompt "" "whether to forcibly push? (yes/no)" "no")
        if math_bool "${xselect}";then
            git push origin ${cur_branch} --force
            retcode=$?
        fi
    fi

    return ${retcode}
}

function glog
{
    local select_x=$(select_one "Author" "Committer" "Time")

    case "${select_x}" in
        "Author")
            git log --author="$@"
            ;;
        "Committer")
            git log --committer="$@"
            ;;
        "Time")
            local tm_s=$(input_prompt "" "input start time" "$(date '+%Y-%m-%d')")
            local tm_e=$(input_prompt "" "input end time" "$(date '+%Y-%m-%d')")
            git log --since="${tm_s}" --until="${tm_e}"
            ;;
        *)
            echo "Nothing"
            return 1
            ;;
    esac

    return 0
}

function gsubmodule_add
{
    local repo="$1"
    local subdir="$2"
    local branch="${3:-master}"

    if [ $# -lt 2 ];then
        echo_erro "\nUsage: [$@]\n\$1: git repository\n\$2: submodule repository directory\n\$3: submodule branch"
        return 1
    fi

    if have_file "${subdir}";then
        echo_erro "sub-directory { ${subdir} } already exists!"
        return 1
    fi

    git submodule add ${repo} ${subdir}

    local retcode=$?
    if [ ${retcode} -eq 0 ];then
        git config -f .gitmodules submodule.${repo}.branch ${branch}
        local retcode=$?
    fi

    return ${retcode}
}

function gsubmodule_del
{
    local repo="$1"

    if [ $# -ne 1 ];then
        echo_erro "\nUsage: [$@]\n\$1: submodule repository"
        return 1
    fi

    git rm --cached ${repo}
    section_del_section .gitmodules "submodule \"${repo}\""
    rm -rf .git/modules/${repo}

    return $?
}

function gsubmodule_update
{
    local repo="$1"

    #if [ $# -ne 1 ];then
    #    echo_erro "\nUsage: [$@]\n\$1: submodule repository"
    #    return 1
    #fi

    if [ -n "${repo}" ];then
        git submodule update --remote ${repo} --recursive
    else

        git submodule update --init --recursive
    fi

    return $?
}
