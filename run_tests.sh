#!/usr/local/bin/bash

blue='\033[0;34m'
l_blue='\033[0;94m'
no_color='\033[0m'

if [ -d $HOME/.rbenv ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi

spec_command="bundle exec spring rspec"
test_command="bundle exec rails test"
declare -A test_mapping=( ["spec"]="it|context|describe" ["test"]="test")
declare -A run_mapping=( ["spec"]=${spec_command} ["test"]=${test_command} )

main() {
    if [[ $1 == *_spec.rb ]] || [[ $1 == *_test.rb ]]; then
        run_tests $1 $2
    else
        find_related_file $1
        if [[ ${related_file} != "" ]]; then
            open_file_in_rubymine ${related_file}
            run_tests ${related_file} 0
        fi
    fi
}

get_git_repo() {
    cd $(dirname "${1}")
    git_repo=`git rev-parse --show-toplevel`
    cd - > /dev/null

}

get_project_folder() {
    get_git_repo $1
    project_folder=${git_repo}
}

get_local_path() {
    get_project_folder
    local_path=`echo $1 | sed "s|${project_folder}/||g"`
}

open_file_in_rubymine() {
    get_project_folder
    cmd="/Applications/RubyMine.app/Contents/MacOS/rubymine ${project_folder} --line 1 ${1}"
    eval ${cmd} > /dev/null
}

find_related_file() {
    for type in "${!test_mapping[@]}"; do
        related_file=`echo "$1" | sed "s/\/app\//\/$type\//g" | sed "s/\.rb/_$type\.rb/g"`

        if [[ ${related_file} == *_"$type".rb ]] && [ -f ${related_file} ]; then
            break;
        else
            related_file=""
        fi
    done
}

testable_line() {
    is_testable=0
    if [[ $1 == "spec" ]]; then
        is_testable=1
        return 0
    fi

    line=`sed "${3}q;d" $2`
    if [[ ${line} =~ \s*("${test_mapping[$1]}")\s* ]]; then
        is_testable=1
        return 0
    fi
}

run_tests() {
    printf "\n${blue}Running tests:${no_color}\n"

    for type in "${!run_mapping[@]}"; do
        if [[ $1 == *_"$type".rb ]]; then
            if [[ ${type} == "test" ]]; then
                cd $(dirname "${1}")
            fi

            testable_line ${type} $1 $2
            get_local_path $1
            full_file=$1
            full_local_path=${local_path}
            if [[ ${is_testable} == 1 ]]; then
                full_file="$1:$2"
                full_local_path="$local_path:$2"
            fi

            cmd="${run_mapping[$type]} ${full_file}"
            viz_cmd="${run_mapping[$type]} ${full_local_path}"

            printf "\n\t${l_blue}${viz_cmd}${no_color}\n\n"
            eval $cmd

            if [[ ${type} == "spec" ]]; then
                cd - > /dev/null
            fi

            break
        fi
    done
}

main $1 $2
