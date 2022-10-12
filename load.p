/*
	ATM performance test:
	Load data into the initial database
	Copyright (c) 1995, Progress Software Corp.

	21-Sep-95 ghb

********************************************************************************
	scale is obtained from the environment variable SCALE.
	It determines the database size in tps. A 1 tps database will have
	100,000 accounts, 100 tellers, and 10 branches. A 150 tps database
	will have 15,000,000 accounts, 15,000 tellers, and 1,500 branches.

	numLoaders is obtained from the environment variable NUMLOADERS.
	it defines the number of processes which will load accounts and
	thus how many accounts each process will load

	loader is obtained from the environment variable LOADER.
	it defines which loader process we are and also which account
	number to start with.
*/
define variable scale           as integer initial 1 no-undo.
define variable numLoaders      as integer initial 1 no-undo.
define variable loader          as integer initial 1 no-undo.

/* ************************************************************************** */
/* scaling constants for the tables - independent of the database size        */

define variable branchesPerTps  as integer initial 10 no-undo.
define variable tellersPerTps   as integer initial 100 no-undo.
define variable acctsPerTps     as integer initial 100000 no-undo.

/* ************************************************************************** */
define variable rowsPerTx       as integer initial 100 no-undo.
define variable acctBalance     as decimal initial 1000.00 no-undo.

define variable n               as integer no-undo.
define variable t               as integer no-undo.
define variable startTime       as integer no-undo.
define variable outname         as character no-undo.

define variable acctsPerMessage as integer no-undo.
define variable nextMessage     as integer no-undo.
define variable apm             as decimal decimals 0 no-undo.
define variable etc             as decimal decimals 0 no-undo.

define variable totalBranches   as integer no-undo.
define variable acctsPerBranch  as integer no-undo.
define variable currentBranch   as integer no-undo.
define variable branchesDone    as integer no-undo.

define variable totalTellers    as integer no-undo.
define variable acctsPerTeller  as integer no-undo.
define variable currentTeller   as integer no-undo.
define variable tellersDone     as integer no-undo.

define variable totalAccounts   as integer no-undo.
define variable accountsToLoad  as integer no-undo.
define variable currentAccount  as integer no-undo.
define variable accountsDone    as integer no-undo.
define variable endingAccount   as integer no-undo.

/* ************************************************************************** */
/* get environment variables */

numLoaders = integer(os-getenv ("NUMLOADERS")).
loader = integer(os-getenv ("LOADER")).
scale = integer(os-getenv ("SCALE")).

/* open our log file */

outname = "build" + string (loader, "99") + ".log".
output to value (outname) unbuffered.

message string (time, "HH:MM")
	"Hello. Loader" loader "of" numLoaders "speaking. Today is" today.
message string (time, "HH:MM")
	"Beginning a" scale "tps load.".

/* Each loader process starts with its loader number and creates a
   portion of the accounts. The first loader puts in the branches
   and tellers. */

totalBranches  = scale * branchesPerTps.
totalAccounts = scale * acctsPerTps.
totalTellers = scale * tellersPerTps.

acctsPerTeller = truncate (totalAccounts / totalTellers, 0).
acctsPerBranch = truncate (totalAccounts / totalBranches, 0).

accountsToLoad = truncate (totalAccounts / numLoaders, 0).
currentAccount = (accountsToLoad * (loader - 1)) + 1.
endingAccount = currentAccount + accountsToLoad - 1.
if (loader = numLoaders) then
do:
    /* if the number of rows does not divide evenly by the number of
       loaders, the last one will do the extra ones to make sure we
       have them all. */

    endingAccount = totalAccounts.
    accountsToLoad = endingAccount - currentAccount + 1.
end.

currentTeller = truncate ((currentAccount - 1) / acctsPerTeller, 0) + 1.
currentBranch = truncate ((currentAccount - 1) / acctsPerBranch, 0) + 1.

/* We give an estimate for when the load will complete and how far it
   has progressed periodically. Each time we have added 5 % of the total
   number of account records we report the estimates */

acctsPerMessage = truncate (accountsToLoad / 20, 0).
nextMessage = currentAccount + acctsPerMessage - 1.

message string (time, "HH:MM")
	totalAccounts "total accounts will be created".
message string (time, "HH:MM")
	totalTellers "total tellers will be created".
message string (time, "HH:MM")
	totalBranches "total branches will be created".
message string (time, "HH:MM")
	"Starting on" accountsToLoad "accounts at account" currentAccount.
message string (time, "HH:MM")
	"Estimated time left will be reported every"
	acctsPerMessage
	"accounts".

accountsDone = 0.
tellersDone = 0.
branchesDone = 0.
t = etime (true).
startTime = time.
arloop:
    do while (currentAccount <= endingAccount) transaction:
	if (currentAccount >= nextMessage) then
	do:
	    /* Time to give a progress report */

	    nextMessage = currentAccount + acctsPerMessage.
	    apm = (acctsPerMessage / etime (true)) * 60000 * numLoaders.
	    etc = (accountsToLoad - accountsDone) * numLoaders / apm.

	    message string (time, "HH:MM")
		    "Did" accountsDone "accounts,"
		    (endingAccount - currentAccount + 1) "left."
		    etc "min to go at" apm "/ min".
	end.

	/* To increase the load speed, we do several rows per transaction,
	   but not all in a single transaction */

        do n = 1 to rowsPerTx:
	    if (currentAccount > endingAccount) then leave arloop.

            if ((currentAccount mod acctsPerBranch) = 1) then
	    do.
/* Branch ... */
	        currentBranch =
		    truncate ((currentAccount - 1) / acctsPerBranch, 0) + 1.

	        create branch.
	        assign
	            branch.id      = currentBranch
	            branch.balance = acctBalance * acctsPerBranch
		    .

		branchesDone = branchesDone + 1.
	    end.
	    if ((currentAccount mod acctsPerTeller) = 1) then
	    do:
/* Teller... */
                currentTeller =
		    truncate ((currentAccount - 1) / acctsPerTeller, 0) + 1.

	        create teller.
	        assign
	            teller.id       = currentTeller
	            teller.branchid = currentBranch
	            teller.balance  = acctBalance * acctsPerTeller
		    .

		tellersDone = tellersDone + 1.
	    end.
/* Account ... */
	    create account.
	    assign
		account.id       = currentAccount
		account.branchid = currentBranch
		account.balance  = acctBalance
		.

	    currentAccount = currentAccount + 1.
	    accountsDone = accountsDone + 1.
        end. /* of 1 to rowsPerTx loop */

    end.

message string (time, "HH:MM")
	accountsDone "Accounts created in" string (time - startTime,"HH:MM").

message string (time, "HH:MM")
        tellersDone "Tellers created".

message string (time, "HH:MM")
        branchesDone "Branches created".

if (loader = 1) then
do transaction:
    /* Now load some default test configurations ... */
    /* Run each test for 5 minutes. 1, 3, 5, and 7 users */
    /* Changed for workshop to be 5 clients for 1 run. */

    do n = 1 to 1:
	create config.
	assign
	    config.id       = n
	    config.program  = "atm1.p"
	    config.clients  = 5
	    config.warmup   = 30
	    config.runtime  = 300
	    config.rundown  = 30
	    .
    end.
end.

message today string (time,"HH:MM") "Loader" loader "finished. Goodbye".

output close.
quit.
