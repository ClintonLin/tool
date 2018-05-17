#!/bin/bash

dultime=30

if [ $dultime -lt 1 ] || [ $dultime -gt 59 ]; then
	echo "time range is [1, 59]"
	exit 0
fi

function usage()
{
	echo "Usage:"
	echo "./cpu.sh threadname threshold"
	echo "eg: ./cpu.sh I2000 80"
}

function pid()
{
	startTime=`date "+%M"`
	let endTime=($startTime+$dultime)%60

	threadname=$1
	threshold=$2

	pid=`ps -ef | grep -v grep|grep "Dprocname=$threadname " | awk -F' ' '{print $2}'`

	threadfile=$threadname.info
	cpufile=$threadname.cpu.info
	tempfile=temp.log

	echo "Time, CPU idle" > $cpufile
	echo "pid, user, %CPU" > $threadfile

	for((;;))
	do
    	datet=`date "+%H:%M:%S"`
	    echo "`top -b -Hp $pid -n 2`" > $tempfile
	    num=`grep -n "%CPU" $tempfile | awk -F: '{print $1}' | tail -n 1`
	    let min=$num+1
	    threadmax=`sed -n "$min"p $tempfile | awk '{print $9}'`
	    if [ `echo " $threadmax  > $threshold " | bc ` -eq 1 ]; then
	        kill -3 $pid
	    fi
	    cpuidle="`grep Cpu $tempfile | awk '{print $5}' | awk -F% '{print $1}' | tail -n 1`"
	    echo "$datet, $cpuidle" >> $cpufile
	    let max=$num+6
	    echo "$datet" >> $threadfile
	    echo "`sed -n "$min","$max"p $tempfile | awk '{print $1, $2, $9}'`" >>$threadfile
	    nowTime=`date "+%M"`
	    if [ $nowTime -eq $endTime ]; then
	        exit 0
	    fi
	done
}

function cpu()
{
    startTime=`date "+%M"`
    let endTime=($startTime+$dultime)%60

    topfile=top.info
	cpufile=cpu.info
    tempfile=temp.log

    echo "Time, CPU idle" > $cpufile
    echo "pid, user, %CPU" > $topfile

    for((;;))
    do
        datet=`date "+%H:%M:%S"`
		echo "`top -b -n 2`" >$tempfile
		cpuidle="`grep Cpu $tempfile | awk '{print $5}' | awk -F% '{print $1}' | tail -n 1`"
        num=`grep -n "%CPU" $tempfile | awk -F: '{print $1}' | tail -n 1`
        let min=$num+1
        echo "$datet, $cpuidle" >> $cpufile
        let max=$num+6
        echo "$datet" >> $topfile
        echo "`sed -n "$min","$max"p $tempfile | awk '{print $1, $2, $9}'`" >>$topfile
        nowTime=`date "+%M"`
        if [ $nowTime -eq $endTime ]; then
            exit 0
        fi
    done	
}

case "$1" in
	'cpu')
		cpu
		;;
	*)
		pid
		;;
esac
