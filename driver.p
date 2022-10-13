/*
        Generic performance test driver
 
        Copyright (c) 1995, Progress Software Corporation

        21-Sep-1995     g bjorklund

	This program will run certain types of benchmarks, record
	and report the results.

	To use it, your database must have the three tables:

	client
		which gets records to record results for
		individual clients for a test run.
	config
		which contains records describing each test run
		you want to do.
	results
		Summary results for each config are stored here.

	What this program does is:
		read all the config records and for each one
		starts as many clients as the config record says,
		running the program specified in the config record.
		Each clients is expected to perform some work for
		a specified amount of time and count how many
		transactions or some such were executed during
		the specified time interval.
		After all clients have finished, the results for
		all the clients together are computed and reported.

*/
def var doHistogram     as logical initial false no-undo.
def var numTests        as integer no-undo.
def var numClients      as integer label "Clients" format ">>9" no-undo.
def var progName        as character             format "x(20)" no-undo.
def var progArgs        as character             format "x(64)" no-undo.
def var clientNo        as integer no-undo.
def var pauseTime       as integer no-undo.
def var endTime         as integer no-undo.
def var didFinish       as logical no-undo.
def var i               as integer no-undo.
def var r               as integer no-undo.
def var totalTx         as integer no-undo.
def var concurrency     as decimal label "Conc"  format ">9.9" no-undo.
def var txPerSec        as decimal label "Tps"   format ">>9.99" no-undo.
def var seconds         as decimal label "Secs"  format ">9.9" no-undo.
def var resPercent      as decimal label "Pct"   format ">,>>9.9" no-undo.
def var cumPercent      as decimal label "Cum %" format ">,>>9.9" no-undo.
def var totResidence    as integer no-undo.
def var resCount        as integer label "Trans" format ">>,>>>,>>9"
				   extent 100 no-undo.
def var lastCountIndex  as decimal no-undo.
def var maxRes          as decimal label "Max R" format ">9.9" no-undo.
def var minRes          as decimal label "Min R" format ">9.9" no-undo.
def var avgRes          as decimal label "Avg R" format ">9.9" no-undo.
def var p50Res          as decimal label "50% R" format ">9.9" no-undo.
def var p90Res          as decimal label "90% R" format ">9.9" no-undo.
def var p95Res          as decimal label "95% R" format ">9.9" no-undo. 
def var peak            as integer initial ? no-undo.
def var periodTps       as decimal label "Tps"   format ">,>>9.9" no-undo.
def var periodTime      as integer label "Sec"   format ">>>9" no-undo.
def var periodStart     as integer no-undo.
def var curPeriod       as integer no-undo.
def var lastPeriod      as integer no-undo.
def var secPerPeriod    as integer initial 5 no-undo.
def var maxPeriod       as integer initial 360 no-undo.
def var histCount       as integer label "Tps" extent 360 no-undo.
def var numHist         as integer no-undo.

def var maxClients      as integer no-undo.
def var minClients      as integer no-undo.
def var maxTps          as integer no-undo.
def var topTps          as integer no-undo.

&IF OPSYS = "WIN32" &THEN
def stream batchStr. 
&ENDIF

output to lastrun.log append unbuffered.

/* make sure there are some records for tests */

numTests = 0.
do for config transaction:
    for each config:
	numTests = numTests + 1.
    end.
end.
if (numTests < 1) then
do:
    message "No test configuration records found. Exiting in disgrace...".
    quit.
end.

message string (time, "HH:MM:SS") "There are" numTests "test records.".

message string (time, "HH:MM:SS") "Deleting old results...".

do for results transaction:
    for each results:
	delete results.
    end.
end.

/* run each test */

for each config:

    /* first compile the test program afresh */

    progName = config.program.
    message string (time, "HH:MM:SS") "Compiling" progName "...".
    compile value(progName) save.

    /* clear history files */

    message string (time, "HH:MM:SS") "Clearing history...".
    numHist = 0.
    do for history1, history2, history3, history4 transaction:
        for each history1:
            numHist = numHist + 1.
            delete history1.
        end.
        for each history2:
            numHist = numHist + 1.
            delete history2.
        end.
        for each history3:
            numHist = numHist + 1.
            delete history3.
        end.
        for each history4:
            numHist = numHist + 1.
            delete history4.
        end.
    end.
    message string (time, "HH:MM:SS") numHist "history records deleted".
    message string (time, "HH:MM:SS") "Deleting old client entries...".
    do for client transaction:
	/* get rid of any old client entries */

        for each client:
            delete client.
        end.

        /* create the control record for the client file. Each client adds a
           record and gets a client number when he starts up */
 
        create client.
        assign
	    client.warmup = config.warmup
	    client.runtime = config.runtime
	    client.rundown = config.rundown
	    .
    end.
 
    do for account transaction:
        numClients = config.clients.
        message string (time, "HH:MM:SS") "Test" config.id progName
		config.client "Clients,"
                "warmup" config.warmup "runtime" config.runtime
		"rundown" config.rundown.
 
        /* Close the starting gate. Each client will do a find on this
	   record when it is ready to start. We release the lock when ready
	   so everybody can start at the same time. */

        find first account exclusive-lock.
 
        /* launch clients */
 
	message string (time, "HH:MM:SS") "Launching clients...".
&IF OPSYS = "WIN32" &THEN
        output stream batchStr to "launch.bat".
        put stream batchStr "@echo off" skip.
        do clientNo = 1 to numClients:
            progArgs = "-p " + progName /* + ">> client" + string(clientNo) + ".log" */ .
            put stream batchStr unformatted "start /d" + os-getenv("CURDIR") + " /min /high /b " + os-getenv("DOCLIENT") + " " + progArgs skip.
        end.
        output stream batchStr close.

        os-command no-wait launch.bat.
&ELSE	
        do clientNo = 1 to numClients:
            progArgs = "-p " + progName + ">> client" +
		      string(clientNo) + ".log 2>&1 &".
            unix silent $DOCLIENT value(progArgs).
        end.
&ENDIF 
        /* Ensure that all are ready to run. Each client creates a client
	   record when he is ready to start. When all have created one
	   then we can open the starting gate. */
 
        pause 20 no-message.
	message string (time, "HH:MM:SS")
		"Checking that all clients started...".
        clientNo = 1.
	pauseTime = 0.
        do while clientNo <= numClients:
	    do for client:
                find client where id = clientNo no-error.
                if available client then
		do:
		    /* this client has started up */

		    clientNo = clientNo + 1.
		    release client.
		end.
                else do:
		    /* this client has not started yet. wait awhile
		       and check again */

                    message string (time, "HH:MM:SS")
			    "Waiting for client" clientNo "to start...".
                    pause 10 no-message.
		    pauseTime = pauseTime + 10.
		end.
	    end.
	    if (pauseTime > 300) then
	    do:
		/* We have waited long enough. Something must be wrong
		   so we will give up. Any clients that started will
		   be waiting on the starting gate which will be
		   opened when we exit and release the lock. They will
		   then run to completion and exit, leaving their
		   individual results in the table */

                message string (time, "HH:MM:SS")
			"Timed out waiting for clients to start.".
                message string (time, "HH:MM:SS")
			"FAILED. Exiting in disgrace. FAILED.".
		quit.
	    end.
        end.
	/* all running - should be ready */

        pause 5 no-message.
 
        /* open the starting gate */
 
        message string (time, "HH:MM:SS") "Opening the starting gate...".
        release account.
    end. /* account */

    pauseTime = config.warmup + config.runtime + config.rundown + 10.
    endTime = time + pauseTime.

    message string (time, "HH:MM:SS") "Waiting until"
            string (endTime, "HH:MM:SS") "...".
    pause pauseTime no-message.
    message string (time, "HH:MM:SS") "Checking all clients finished...".

    /* wait for all the client to update their client record, indicating
       that they have completed their transactions */

    do i = 1 to 100: resCount[i] = 0. end.
    clientNo = 1.
    pauseTime = 0.
    totResidence = 0.
    maxRes = 0.
    totalTx = 0.
    do while clientNo <= numClients:
	didFinish = false.
	do for client transaction:
            find client where id = clientNo.
            if finish > 0 then
	    do:
		/* This client has finished, advance to the next */

		clientNo = clientNo + 1.
		didFinish = true.
		pauseTime = 0.
	    end.
        end.
	if (didFinish = false) then
	do:
	    if (pauseTime > 600) then
	    do:
		/* We have waited long enough. Something must be wrong */

                message string (time, "HH:MM:SS")
			"Timed out waiting for clients to finish.".
                message string (time, "HH:MM:SS")
			"FAILED. Exiting in disgrace. FAILED.".
		quit.
	    end.

	    /* wait a few seconds to see if this client finishes */

            message string (time, "HH:MM:SS")
		    "Waiting for client" clientNo "to finish...".
	    pauseTime = pauseTime + 10.
	    pause pauseTime no-message.
	end.
    end.
    message string (time, "HH:MM:SS") "Computing results...".

    /* Get each client's results and summarize them.
       There are counter buckets for every 0.1 sec interval up to 9.9
       seconds in the resCount array. The last bucket is for times
       greater than 9.9 seconds. */

    lastCountIndex = 0.
    minRes = 9999.
    for each client transaction:
	do i = 1 to 99:
	    resCount[i] = resCount[i] + client.residence[i].
	    if (resCount[i] <> 0) then
	    do:
	        lastCountIndex = i.
	        if (i < minRes) then minRes = i.
	        if (i > maxRes) then maxRes = i.
	    end.
	end.
	resCount[100] = resCount[100] + client.residence[100].
	if (maxRes < client.topres) then maxRes = client.topres.
	totResidence = client.totres + totResidence.
	totalTx = client.numtx + totalTx.
    end.

    /* Convert the bucket numbers to seconds */

    maxRes = (maxRes - 1) / 10.
    minRes = (minRes - 1) / 10.

    if (doHistogram) then
    do for history1:
        message string (time, "HH:MM:SS")
		"Generating time/tps histogram...".

        /* Loop over all the history1 records and count how many transactions
           for each 10 second period  (up to 360 periods, 1 hour) */

        do curPeriod = 1 to maxPeriod: histCount[curPeriod] = 0. end.
	peak = 0.
	lastPeriod = 1.
        find first history1.
	if not available history1 then leave.
	periodStart = history1.trx_time.

        for each history1 no-lock:
            curPeriod = ((history1.trx_time - periodStart) / secPerPeriod) + 1.
	    if (curPeriod > maxPeriod) then curPeriod = maxPeriod.
	    if (curPeriod > lastPeriod) then lastPeriod = curPeriod.
	    histCount[curPeriod] = histCount[curPeriod] + 1.
        end.

        /* print the results */

	do curPeriod = 1 to lastPeriod:
	    periodTps = histCount[curPeriod] / secPerPeriod.
	    if (periodTps > peak) then peak = periodTps.
	    i = (histCount[curPeriod] / secPerPeriod) / 2.
	    periodTime = curPeriod * secPerPeriod.
	    display periodTime periodTps fill ("*", i) format "x(50)"
		    with down frame hist-frame no-box.
            down 1 with frame hist-frame. 
	end.
    end.

    /* Calculate and display concurrency and residence time.

       Concurrency is an approximate measure of the number of transactions
       which were executing concurrently. This will be less than
       the number of generators because each generator executes 
       code which is not part of the transaction being measured.

       "residence" time is approximately the time from transaction
       begin to transaction end.
       
       We are only interested in the 50, 90, and 95 percentiles.
       Perhaps we should do 20 increments of 5%. */

    message string (time, "HH:MM:SS") "Calculating residence times...".
    txPerSec = totalTx / config.runtime.
    avgRes = totResidence / totalTx / 1000.
    concurrency = avgRes * txPerSec.
    cumPercent = 0.
    p95Res = ?.
    p90Res = ?.
    p50Res = ?.
    seconds = 0.
    do r = 1 to lastCountIndex:
        resPercent = (resCount[r] * 100 / totalTx).
        cumPercent = cumPercent + resPercent.
	if ((cumPercent >= 50) and (p50Res = ?)) then p50Res = seconds.
	if ((cumPercent >= 90) and (p90Res = ?)) then p90Res = seconds.
	if ((cumPercent >= 95) and (p95Res = ?)) then p95Res = seconds.
        if (cumPercent <= 99.0) or (seconds <= 1.0) then
        do:
            display
                seconds
                resCount[r]
                cumPercent
                resPercent
                fill ("*", integer (resPercent / 2)) format "x(50)"
                with down frame res-frame. 
            down 1 with frame res-frame. 
        end.
        else if (resPercent > 0) then
        do:
	    /* only nonzero values after 99 % have been reported */

            display
                seconds
                resCount[r]
                cumPercent
                resPercent
                with down frame res-frame. 
            down 1 with frame res-frame. 
        end.
	seconds = seconds + 0.1.
    end.
 
    /* Save the results for this test in the results record */
 
    message string (time, "HH:MM:SS") "Updating results table...".
    do for results transaction:
	create results.
	assign
	    results.id          = config.id
	    results.program     = config.program
	    results.clients     = config.clients
	    results.numtx       = totalTx
	    results.tps         = txPerSec
	    results.maxtps      = peak
	    results.avgres      = avgRes
	    results.p50res      = p50Res
	    results.p90res      = p90Res
	    results.p95res      = p95Res
	    results.maxres      = maxRes
	    results.minres      = minRes
	    results.concurrency = concurrency
	    .

        /* display them in the log file so we can see how we are doing */
 
        display
            results.id
            results.clients
            results.runtime
            results.numtx
            results.tps
	    results.concurrency
	    results.avgres
	    results.minres
	    results.p50res
	    results.p90res
	    results.p95res
	    results.maxres
		with frame log-frame.
    end. 
end. /* for each config */
 
message string (time, "HH:MM:SS") "Generating summary data...".
maxTps = 0.
maxClients = 0.
minClients = 999.

for each results:
    if (maxTps < results.tps) then maxTps = results.tps.
    if (results.clients > maxClients) then maxClients = results.clients.
    if (minClients > results.clients) then minClients = results.clients.
end. 

topTps = 10.
if (maxTps > 10) then topTps = 25.
if (maxTps > 25) then topTps = 50.
if (maxTps > 50) then topTps = 100.
if (maxTps > 100) then topTps = 150.
if (maxTps > 150) then topTps = 200.
if (maxTps > 250) then topTps = 300.
if (maxTps > 350) then topTps = 400.
if (maxTps > 450) then topTps = 500.
if (maxTps > 550) then topTps = 600.
if (maxTps > 650) then topTps = 700.
if (maxTps > 750) then topTps = 800.
if (maxTps > 850) then topTps = 900.
if (maxTps > 950) then topTps = 1000.

display "             "
	(topTps / 5)       format ">>>>>>>>9"
	((topTps * 2) / 5) format ">>>>>>>>9"
	((topTps * 3) / 5) format ">>>>>>>>9"
	((topTps * 4) / 5) format ">>>>>>>>9"
	topTps             format ">>>>>>>>9"
	with frame gf1 no-box no-labels.

display "Clients  Tps |--------|---------|---------|---------|---------|"
	with frame gf2 no-box no-labels.

for each results:
    i = (results.tps * (50 / topTps)).
    display
        results.clients format ">>,>>>,>>9" no-label
        results.tps format ">,>>9.9" no-label
	fill ("*", i) format "x(50)"  no-label
        with frame gf3 no-box no-labels.
end.
display "Clients  Tps |--------|---------|---------|---------|---------|"
	with frame gf4 no-box no-labels.

message string (time, "HH:MM:SS") "This run is DONE. Updating summary log.".

/* append new results to the summary report */
 
output to temp.log append.

for each results:
    display
        results.clients
        results.runtime
        results.numtx
        results.tps
        results.concurrency
        results.avgres
        results.minres
        results.p50res
        results.p90res
        results.p95res
        results.maxres
        with frame summary-frame 15 down.
end.
 
output close.

/* Append the summary log */

os-append temp.log summary.log.
os-delete temp.log.

&IF OPSYS = "WIN32" &THEN
os-delete launch.bat.
&ENDIF

/* append the detailed log */

os-append lastrun.log allruns.log.
