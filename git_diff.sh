#!/usr/bin/bash

# ##############################################################################
# 获取单个文件改动记录
# cd /mnt/e/Source/bbc/bbc/BBC2.5.16/
# base_commit_id=$(git rev-parse --verify remotes/origin/master)
# compare_commit_id=$(git rev-parse --verify remotes/origin/2.5.18-master)
# file_item=Alternate/source/build/root/sf/bin/bbc_ha
# git log ${base_commit_id}..${compare_commit_id} $file_item
# ##############################################################################

set -e


# 用一个不可能在提交记录中出现的字符粗来替换换行符，规避 sed 命令无法解析替换字符串包含换行符的问题
# 没办法解决 sed 命令中，替换的字符串包含回车字符的情况；曲线救国：把 \n 换行符替换成 | ，最后再把 | 替换回去
ctrl_rep="\^"

# 日志文件
work_dir=$(pwd)/$0.tmp/
mkdir -p "$work_dir"
log_file=${work_dir}/git_diff.log
>$log_file

# 输出文件
output_file=

# 上一版本代码仓库
pre_version_git_repository=

# 上一版本的主线分支
base_branch=
base_commit_id=

# 当前版本的主线分支
compare_branch=
compare_commit_id=

# 需要排除掉的代码路径关键字
exclude_key_word=

# 当前版本仓库代码目录
curr_version_git_repository=


function usage()
{
cat << HELP
function:
    compure current version and previous version's files change, and format output to a csv file.

usage: 
    --pre_version_git_repository  previous version source code path, like /mnt/e/Source/bbc/bbc/BBC2.5.16
    --curr_version_git_repository  current version source code path, like /mnt/e/Source/bbc/bbc/BBC2.5.18
    --base_branch         base branch, like master
    --compare_branch      compare branch with base branch, like 2.5.18master
    --exclude_key_word    exclude path has those key words, like webui

example:
    # push current version master branch to previous version git repository

    cd $curr_version_git_repository
    git remote add 2516 git@code.sangfor.org:CN/BBC/BBC2.5.16.git
    git checkout master
    git checkout -b 2.5.18-master
    git push 2516 2.5.18-master

    cd $pre_version_git_repository
    git pull -p

    # get the difference files and the merge request message to csv file.
    bash git_diff.sh --pre_version_git_repository /mnt/e/Source/bbc/bbc/BBC2.5.16 --curr_version_git_repository /mnt/e/Source/bbc/bbc/BBC2.5.18 --base_branch master --compare_branch 2.5.18-master --exclude_key_word webui

HELP
    exit 1;
}

function param_parse()
{
    [ $# -eq 0 ] && usage
    # ARGS=`getopt -a -o c::i::s::p::u::h -l clean::,install::,src::,update::,pkg::,help -- "$@"`
    # if [ $? -ne 0 ]; then
    #     usage;
    #     die 1 "arg error";
    # fi
    # eval set -- "${ARGS}"
 
    while true 
    do
        case "$1" in
        --pre_version_git_repository)
            pre_version_git_repository=$2
            shift;
            ;;
        --curr_version_git_repository)
            curr_version_git_repository=$2
            shift;
            ;;
        --base_branch)
            base_branch=$2
            shift;
            ;;
        --compare_branch)
            compare_branch=$2
            shift;
            ;;
        --exclude_key_word)
            exclude_key_word=$2
            shift;
            ;;
        -h|--help)
            usage;
            shift;
            ;;
        *)
            if [ "$2" != "" ]; then
                usage;
                die "$ERROR arg is unknown";
            fi
            # shift;
            break;
            ;;
        esac
    shift
    done

    echo "arg is:
    pre_version_git_repository=$pre_version_git_repository
    curr_version_git_repository=$curr_version_git_repository
    base_branch=$base_branch
    compare_branch=$compare_branch
    exclude_key_word=$exclude_key_word
    "

    # show args
}

function get_branch_diff_output()
{
    # 版本改动文件输出路径
    output_file=${work_dir}/git_diff.csv
    output_tmp_file=$(mktemp)

    # 排除GIT文件路径关键字
    # TODO exclude_key_word 必须有值才行。。。
    grep_exclude_file=$(mktemp)
    echo "$exclude_key_word" > "$grep_exclude_file"

    cd "$pre_version_git_repository"

    # 两个版本的提交ID
    base_commit_id=$(git rev-parse --verify remotes/origin/"$base_branch")
    ret=$?
    if [ "$ret" != 0 ]; then
        echo "check if the branch $base_branch is exist"
        exit $ret
    fi
    compare_commit_id=$(git rev-parse --verify remotes/origin/"$compare_branch")
    ret=$?
    if [ "$ret" != 0 ]; then
        echo "check if the branch $base_branch is exist"
        exit $ret
    fi


    # 获取版本间改动文件
    # 并按csv格式，并用逗号分隔 比如: A,Alternate/source/build/boot/update/rebooted/01-mv_old_qoe_data.up
    git diff "$base_commit_id" "$compare_commit_id" --name-status | grep -v -f "$grep_exclude_file" | awk '{OFS=","; print $1,$2}' | sort > "$output_tmp_file"
}

# 提交历史转义/过滤
function commit_history_cmd_filter()
{
    # git log 命令
    file_history=$($1 | tr "\n" "${ctrl_rep}" | tr "!" " " | tr "\"" " ")
    echo "$file_history"
}

function get_files_history()
{
    # 追加每个文件的合并记录
    files=$1

    for file_item in $files; do
        # 过滤 ! （会被当成 bash 历史命令执行）
        # 没办法解决 sed 命令中，替换的字符串包含回车字符的情况；曲线救国：把 \n 换行符替换成 | ，最后再把 | 替换回去
        # 提交历史不能包含双引号，会影响 csv 的单元格内换行
        # commit_history=$(commit_history_cmd_filter "git log --no-merges --after=\"2020-1-1\" ${base_commit_id}..${compare_commit_id} $file_item ")
        # commit_history=$(commit_history_cmd_filter "git log --no-merges ${base_commit_id}..${compare_commit_id} $file_item ")
        commit_history=$(commit_history_cmd_filter "git log ${base_commit_id}..${compare_commit_id} $file_item ")

        echo "handling: [$file_item]" >> $log_file

        if [ x"${commit_history}" != x"" ]; then
            sed -i "s~${file_item}~${file_item},\"${commit_history}\"~g" "$output_tmp_file"
            if [ $? != 0 ]; then
                echo "ERROR: ${file_item}" >> $log_file
                echo "ERROR: ${commit_history}" >> $log_file
                echo "ERROR: sed -i \"s~${file_item}~${file_item},${commit_history}~g\" $output_tmp_file" >> $log_file
                echo "" >> log_file
            fi
        else
            echo "WARN: $file_item has no commit history: $commit_history" >> log_file
        fi
    done
}

function get_modify_files_history()
{
    echo "==================== ========================== ====================" >> $log_file
    echo "==================== [get modify files history] ====================" >> $log_file
    echo "==================== ========================== ====================" >> $log_file
    # 改动文件列表
    modify_files=$(git diff "$base_commit_id" "$compare_commit_id" --name-only --diff-filter=M | grep -v -f "$grep_exclude_file" | sort)

    get_files_history "$modify_files"
}

function get_new_files_history()
{
    echo "==================== ========================== ====================" >> $log_file
    echo "==================== [get   add  files history] ====================" >> $log_file
    echo "==================== ========================== ====================" >> $log_file

    # 新增文件列表
    new_files=$(git diff "$base_commit_id" "$compare_commit_id" --name-only --diff-filter=A | grep -v -f "$grep_exclude_file" | sort)

    cd "$curr_version_git_repository"
    for add_file_item in $new_files; do
        # 新增文件不需要过滤时间
        commit_history=$(commit_history_cmd_filter "git log $add_file_item ")

        if [ "x${commit_history}" != "x" ]; then
            sed -i "s~${add_file_item}~${add_file_item},\"${commit_history}\"~g" "$output_tmp_file"
        else
            echo "WARN: $add_file_item has no commit history: $commit_history" >> log_file
        fi
    done
}

function get_delete_files_history()
{
    echo "==================== ========================== ====================" >> $log_file
    echo "==================== [get delete files history] ====================" >> $log_file
    echo "==================== ========================== ====================" >> $log_file

    # 删除文件列表
    delete_files=$(git diff "$base_commit_id" "$compare_commit_id" --name-only --diff-filter=D| grep -v -f "$grep_exclude_file" | sort)

    get_files_history "$delete_files"
}

# 把提交历史还原成原来的样子（换行）
function format_commit_history()
{
    sed -i "s~${ctrl_rep}~\\n~g" "$output_tmp_file"
    mv "$output_tmp_file" "$output_file"
}


function main()
{
    echo "comparing $base_branch and $compare_branch ..."
    get_branch_diff_output

    echo

    echo "handling modify files history ..."
    get_modify_files_history

    echo

    echo "handling delete files history ..."
    get_delete_files_history

    echo

    echo "handling new files history ..."
    get_new_files_history

    echo

    echo "generating result to $output_file ..."
    format_commit_history

    echo

    echo "all mission is success."
    exit 0
}

param_parse "$@"

main
