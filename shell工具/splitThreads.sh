#!/bin/bash
[ "$#" != "1" ] && echo "parameters is error." && exit 1

inputFile=$1

currentFile="No"

while read line
do
    if [[ "$line" == *Thread\ 0x* ]];then
        fileName=$(echo $line | awk '{print $2}')
        touch $fileName
        currentFile=$fileName
        echo $line >> $currentFile
    fi
    if [ "$currentFile" != "No" ];then
        echo $line >> $currentFile
    fi
    if [ "$line" == "" ];then
        currentFile="No"
        continue
    fi
done < $inputFile
