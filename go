#!/bin/bash
#
# ATM performanc test:
# start a new test run
# 21-Sep-95 ghb
#
cat version.txt
#
CURDIR=`pwd`
#
# where are we ?
#
HOSTNAME=`hostname`
#
PROPATH=:$CURDIR
#CPUS=`online -N`
CPUS=1
#
: ${DLC?'You forgot to set DLC'} 
: ${CURDIR?'You forgot to set CURDIR'}
#
#
DBNAME=atm
FQDB=/data/db/$DBNAME
DRIVER="driver.p"
RUNLOG="lastrun.log"
TEMPLOG="temp.log"
STARTLOG="startup.log"
HISTORY="allruns.log"
SUMMARY="summary.log"
#
# Take executables from here
#
DLCBIN=$DLC/bin
#
PROSV=$DLCBIN/_mprosrv
PROCL=$DLCBIN/_progres
PROAPW=$DLCBIN/_mprshut
PROBIW=$DLCBIN/_mprshut
PROAIW=$DLCBIN/_mprshut
#
NUMAPW=1
BIW="yes"
AIW="no"
#
# Server options
#
SVOPT1="-n 20 -L 512"
SVOPT2="-B 3000"
SVOPT3="-bibufs 20"
#
CLOPT="-l 5"
#
DOCLIENT="$PROCL $FQDB $TCPOPTS -b -rand 2"
DODRIVER="$PROCL $FQDB $TCPOPTS -b -rand 2 -p $DRIVER"
#
# do it
#
export TEMPLOG RUNLOG PROPATH DBNAME DOCLIENT
#
# start the test
#
    if [ -z "$TCPOPTS" ] 
    then 
        echo connecting with $TCPOPTS
    elif [ -f $FQDB.db ]  
    then
        echo "Using database $FQDB."
    else
        echo "There is no database called $FQDB."
        echo "Exiting in disgrace."
        exit 1
    fi

    if [ -f $FQDB.lk ] || [ "$TCPOPTS" != "" ]  
    then
#
# start driver now
#
        echo "$FQDB database is up."
	echo "Starting test driver $DRIVER, but first"
        echo "we sleep 5 seconds in case you forgot something..."
        sleep 5
        echo "Results will be written to $RUNLOG."
        date >$TEMPLOG
        echo >>$TEMPLOG
        date >>$RUNLOG
        $DODRIVER >>$RUNLOG 2>&1 &
	echo "The test has been started in the background."
	echo "Tail $RUNLOG to find out when it has finished."
        exit
    fi
#
# need to start database
#
    if [ "$TCPOPTS" != "" ]
    then
        echo start the database, TCPOPTS=$TCPOPTS
        exit 1
    fi

    echo "Starting $DBNAME database using $PROSV, but first"
    echo "we sleep 5 seconds in case you forgot something..."
    sleep 5
    rm -f client*.log
#
# log a few things
#
    echo "Logging startup to $STARTLOG and $RUNLOG."
    cat version.txt >$STARTLOG
    date >>$STARTLOG
    echo "Machine name $HOSTNAME" >>$STARTLOG
    echo Modules: >>$STARTLOG
    echo $PROSV >>$STARTLOG
    echo $PROCL >>$STARTLOG
    echo $PROAPW >>$STARTLOG
    echo Server options: >>$STARTLOG
    echo sv opt 1: $SVOPT1 >>$STARTLOG
    echo sv opt 2: $SVOPT2 >>$STARTLOG
    echo sv opt 3: $SVOPT3 >>$STARTLOG
    echo Page cleaners: $NUMAPW, BI writer: $BIW, AI writer: $AIW >>$STARTLOG
    echo >>$STARTLOG
    cat $STARTLOG >$RUNLOG
    echo >>$SUMMARY
    cat $STARTLOG >>$SUMMARY
#
# start server
#
    echo "Start $DBNAME database ..." | tee -a $RUNLOG
    $PROSV $FQDB $SVOPT1 $SVOPT2 $SVOPT3 >>$RUNLOG 2>&1
    sleep 3
#
# start before image writer
#
    if [ "$BIW" = "yes" ]
    then
        echo "Start before image writer ..." | tee -a $RUNLOG
        $PROBIW $FQDB -C biw 2>&1 >>$RUNLOG &
    fi
#
# start after image writer
#
    if [ "$AIW" = "yes" ]
    then
        echo "Start after image writer ..." | tee -a $RUNLOG
        $PROAIW $FQDB -C aiw 2>&1 >>$RUNLOG &
    fi
#
# start page cleaners (try 1 per db disk + 1 extra)
#
    while [ $NUMAPW -gt 0 ]
    do
        echo "Start page writer $NUMAPW ..." | tee -a $RUNLOG
        $PROAPW $FQDB -C apw 2>&1 >>$RUNLOG &
        NUMAPW=`expr $NUMAPW - 1`
    done
#
    date >>$RUNLOG
    echo "Database $FQDB should now be running."
    echo "Type $0 again to start the test driver."
