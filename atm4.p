/*
	ATM performance test:
	Transaction generator
	This version uses multiple history tables.
	Copyright (c) 1995, Progress Software Corporation

	21-Sep-1995     g bjorklund
*/
define variable theAccount      like account.id no-undo.
define variable theBranch       like branch.id no-undo.
define variable actBranch       like branch.id no-undo.
define variable theTeller       like teller.id no-undo.

define variable lastAccount     as integer no-undo.
define variable lastBranch      as integer no-undo.
define variable lastTeller      as integer no-undo.

define variable delta           as decimal initial 0.01 no-undo.
define buffer   myClient           for client.
define variable clientNo        as integer no-undo.
define variable warmupTx        as integer initial 0 no-undo.
define variable txCount         as integer initial 0 no-undo.
define variable rundownTx       as integer initial 0 no-undo.
define variable nhist           as integer initial 0 no-undo.
define variable txId            as integer initial 0 no-undo.
define variable txDate          as date no-undo.
define variable txTime          as integer no-undo.
define variable txStartMs       as integer no-undo.
define variable txEndMs         as integer no-undo.
define variable testStartMs     as integer no-undo.
define variable testEndMs       as integer no-undo.
define variable quitMs          as integer no-undo.
define variable startTime       as integer no-undo.
define variable endTime         as integer no-undo.

define variable r               as integer no-undo.
define variable totResidence    as integer no-undo.
define variable maxResidence    as integer no-undo.
define variable resCnts         as integer extent 100 no-undo.

do r = 1 to 100:
    resCnts[r] = 0.
end.

/* Find out how big the database is. The database is scaled so that there
   are 10,000 accounts per branch and 10 tellers per branch. This gives
   1,000 accounts per teller. */

do for account transaction:
    find last account.
    lastAccount = account.id.
    lastBranch = truncate (lastAccount / 10000, 0).
    lastTeller = truncate (lastAccount / 1000, 0).
end.

do transaction:
    /* get the next available generator number. numtx in record 0
       is used for this purpose (there is no generator number 0). */

    find client 0 exclusive.
    client.numtx = client.numtx + 1.
    clientNo = client.numtx.

    /* create the record where we store the results for the driver to
       look at */

    create myClient.
    assign
        myClient.id = clientNo
        myClient.warmup = client.warmup
	myClient.runtime = client.runtime
	myClient.rundown = client.rundown
	.

    /* get the number of milliseconds to beginning of each phase. warmup
       starts at 0. */

    testStartMs =               (myClient.warmup * 1000).
    testEndMs   = testStartMs + (myClient.runtime * 1000).
    quitMs      = testEndMs   + (myClient.rundown * 1000).
end.
release client.

/* wait for starting gate to open. The driver will unlock this record when
   it has started all the generators and they have created their clienclient record
   and a few extra seconds have elapsed */

do for account transaction:
    find first account.
end.

/* set the elapsed time counter to zero */

txId = clientNo * 10000000.
startTime = time.
r = etime (TRUE).

txloop:
do while (true):

    delta = random (-999999, 999999) / 100.

    /* Generate account, branch, and teller numbers */

    theTeller  = random (1, lastTeller).
    theBranch  = truncate (((theTeller - 1) / 10), 0) + 1.
    if (random (1, 100) < 85) then
    do:
	/* 85% of the time we want an account from the teller's branch */

       actBranch = theBranch.
    end.
    else
    do while (true):
	/* 15 % of the time we want an account from a "remote" branch */

	actBranch = random (1, lastBranch).
	if (actBranch <> theBranch) then leave.
    end.
    /* pick an account within the account's branch */

    theAccount = random (1, 10000) + ((actBranch  - 1) * 10000).

    /* get date, time and bump the transaction counter */

    txDate = today.
    txTime = time.

    /* A unique index value for the history table */

    nhist = random (1, 4).
    txId = txId + 1.

    /* now do one transaction */

    txStartMs = etime.
    do for account, branch, teller, history1, history2, history3, history4
	   transaction:

	/* retrieve and update account */

	find account where account.id = theAccount exclusive-lock.
        assign account.balance = account.balance + delta.

	/* create history record */

        if (nhist = 4) then
	do:
	    create history4.
	    assign
	        history4.trx_id    = txId
	        history4.trx_date  = txDate
	        history4.trx_time  = txTime
	        history4.account   = theAccount
	        history4.teller    = theTeller
	        history4.branch    = theBranch
	        history4.delta     = delta
	        history4.balance   = account.balance
		.
	end.
        if (nhist = 3) then
	do:
	    create history3.
	    assign
	        history3.trx_id    = txId
	        history3.trx_date  = txDate
	        history3.trx_time  = txTime
	        history3.account   = theAccount
	        history3.teller    = theTeller
	        history3.branch    = theBranch
	        history3.delta     = delta
	        history3.balance   = account.balance
		.
	end.
        if (nhist = 2) then
	do:
	    create history2.
	    assign
	        history2.trx_id    = txId
	        history2.trx_date  = txDate
	        history2.trx_time  = txTime
	        history2.account   = theAccount
	        history2.teller    = theTeller
	        history2.branch    = theBranch
	        history2.delta     = delta
	        history2.balance   = account.balance
		.
	end.
        if (nhist = 1) then
	do:
	    create history1.
	    assign
	        history1.trx_id    = txId
	        history1.trx_date  = txDate
	        history1.trx_time  = txTime
	        history1.account   = theAccount
	        history1.teller    = theTeller
	        history1.branch    = theBranch
	        history1.delta     = delta
	        history1.balance   = account.balance
		.
	end.

	/* retrieve and update teller */

	find teller where teller.id = theTeller exclusive-lock.
        assign teller.balance = teller.balance + delta.

	/* retrieve and update branch */

	find branch where branch.id = theBranch exclusive-lock.
        assign branch.balance = branch.balance + delta.

    end. /* of transaction block */
    txEndMs = etime.

    if (txStartMs >= testStartMs) and (txEndMs <= testEndMs) then
    do:
	/* We started and ended within the measurement period - The
	   transaction counts */

	txCount = txCount + 1.

	/* Update residence time counter bucket.
	   There is one bucket for every 100 ms up to 9.9 sec.
	   Any over 9.9 are counted in the last bucket */

        r = txEndMs - txStartMs.
        totResidence = totResidence + r.
	r = (r / 100) + 1.

	if (r > maxResidence) then maxResidence = r.
	if (r > 100) then r = 100.

	resCnts[r] = resCnts[r] + 1.
	next txloop.
    end.
    if (txEndMs < testStartMs) then
    do:
	/* We are still in the warmup period - The transaction
	   does not count */

        warmupTx = warmupTx + 1.
	next txloop.
    end.
    /* We are in the rundown period - The transaction does not count */

    rundownTx = rundownTx + 1.
    if (txEndMs >= quitMs) then leave txloop.

end. /* of timed test loop */
endTime = time.

/* record finish time and number of transactions */

message string (startTime, "HH:MM:SS") string (time, "HH:MM:SS")
	"Client" clientNo
	"done -" warmupTx txCount rundownTx.

do transaction:
    myClient.start = startTime.
    myClient.finish = endTime.
    myClient.numtx = txCount.
    myClient.topres = maxResidence.
    myClient.totRes = totResidence.
    do r = 1 to 100:
	myClient.residence[r] = resCnts[r].
    end.
end.
