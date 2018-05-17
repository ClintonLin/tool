#!/bin/bash
function die
{
    echo "$@"
    exit 1
}

[ "$#" != "2" ] && die "Arguments is invalid."

doExtrJarArchive()
{
    doExtrZipArchive $1 $2
}

doExtrZipArchive()
{
    local archiveFile=$1
    local extractDir=$2
    unzip $archiveFile -d $extractDir > /dev/null 2>&1
}

doExtrTargzArchive()
{
    local archiveFile=$1
    local extractDir=$2
    tar -zxvf $archiveFile -C $extractDir > /dev/null 2>&1
}

getExtName()
{
    local fileName=$1
    echo $fileName | awk -F"." '{print $NF}'
}

doExtractArchive()
{
    local archiveFile=$1
    local extName=$(getExtName $archiveFile)
    echo $filterExtName | grep "$extName" > /dev/null 2>&1
    [ $? -ne 0 ] && return
    local archiveFileName=$(basename $archiveFile | sed "s/\.$extName//g" )
    local archiveDirName=$(dirname $archiveFile)
    mkdir -p $archiveDirName/$archiveFileName
    if [[ "$archiveFile" == *.zip ]];then
        doExtrZipArchive "$archiveFile" "$archiveDirName/$archiveFileName"
    elif [[ "$archiveFile" == *.tar.gz ]];then
        doExtrTargzArchive "$archiveFile" "$archiveDirName/$archiveFileName"
    else
        echo "Arguments is not zip or tar.gz."
        return
    fi
    if [ "$archiveFile" != "$firstArchiveFile" ];then
        rm $archiveFile
    fi
    while [ 1 ]
    do
        local isExtract=false
        for archiveFile in `find $archiveDirName/$archiveFileName  \( -name '*.zip' -o -name '*.tar.gz' \)`
        do
            if [ -f $archiveFile ];then
                doExtractArchive "$archiveFile"
            fi
            isExtract=true
        done
        if [ "$isExtract" == "false" ];then
            break
        fi
    done

}
filterExtName="$2"
firstArchiveFile="$1"
doExtractArchive "$1"