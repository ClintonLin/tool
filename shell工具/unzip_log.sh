#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
CurrentPath="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


function die()
{
    echo "$@"
    exit 1
}

function checkParam()
{
    [ $# -ne 2 ] && echoHelpInfo
}

function echoHelpInfo()
{
    echo "Usage: sh $0 -k <keyword>

    -k : keyword
         The keyword of log file."

    echo ""
}

function main()
{
    checkParam $@

    case $1 in

        '-k')
            KEYWORD=$2
            [ x${KEYWORD} = x'' ] && die "Please input the keyword of log file."
            num=1
            for zipfile in $(ls -l ${KEYWORD}*zip | grep -v total | awk '{print $9}');do
                logfile=$(unzip -o ${zipfile} | grep inflating | awk '{print $2}')
                mv ${logfile} ${KEYWORD}.${num}.log
                num=$[num+1]
            done
        ;;

        *)
            die "Please input correct param."
        ;;

    esac

    echo "Finish."
}

#for i in {1..10};do
#    echo $i
#done

main $@

exit 0
