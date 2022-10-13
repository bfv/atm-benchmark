@echo off
rem ATM performance test:
rem Create ATM database
rem 21-Sep-95 ghb
rem 11-Apr-02 tku

type version.txt
if not defined DLC goto nodlc

set CURDIR=C:\PROGRESS\CLASS\ATM
set PROPATH=%CURDIR%
set DBNAME=atm
set SCALE=10
set NUMLOADERS=4
set CLSZ=2048
set BIBSZ=16
set LOG=build.log
set HISTORY=allruns.log
set SUMMARY=summary.log
set EMPTYDB=%DLC%\empty

set UTILBIN=%DLC%\bin
set PROUTIL=%UTILBIN%\_proutil
set PROCOPY=%UTILBIN%\_dbutil procopy
set PROSTRCT=%UTILBIN%\_dbutil prostrct

set EXEBIN=%DLC%\bin
set PROSV=%EXEBIN%\_mprosrv
set PROCL=%EXEBIN%\_progres
set PROAPW=%EXEBIN%\_mprshut
set PROBIW=%EXEBIN%\_mprshut
set PROAIW=%EXEBIN%\_mprshut

rem Server options
set SVOPT1=-n 20 -L 1024
set SVOPT2=-B 1000
set SVOPT3=-bibufs 20
set CLNOPT1=-b
set LDROPT1=-b

rem *******************************************************************
rem Some sanity checks...
if exist %DBNAME%.lk goto dbrunning
if exist %DBNAME%.db goto dbexists
if not exist %DBNAME%.st goto nost
echo %DBNAME%.st contains... >> %SUMMARY%

rem give the guy a chance to change his mind
echo Build %SCALE% tps %DBNAME% database using %NUMLOADERS% processes
echo You can press CTRL-C to cancel if you forgot something.
pause
del build*.log

rem *******************************************************************
rem Now create the database
type version.txt > %LOG%
(date /t & time /t ) >> %LOG%

echo Create void %DBNAME% database using %DBNAME%.st ... >> %LOG%
type %DBNAME%.st >> %LOG%
echo. >> %SUMMARY%
(date /t & time /t) >> %SUMMARY%
echo. >> %SUMMARY%
echo %CURDIR% >> %SUMMARY%
type %DBNAME%.st >> %SUMMARY%
echo. >> %SUMMARY%
%PROSTRCT% create %DBNAME%
echo Copy empty database into %DBNAME% ... >> %LOG%
%PROCOPY% %EMPTYDB% %DBNAME%

rem truncate the bi file and set cluster size
echo Cluster size is %CLSZ%. >> %LOG%
echo BI block size is %BIBSZ%. >> %LOG%
echo Truncate %DBNAME%.bi ... >> %LOG%
%PROUTIL% %DBNAME% -C truncate bi -G 1 -bi %CLSZ% -biblocksize %BIBSZ%
echo. >> %LOG%

rem start the server
echo Starting server for %DBNAME% ... >> %LOG%
echo Server options: >> %LOG%
echo Sv opt 1: %SVOPT1% >> %LOG%
echo Sv opt 2: %SVOPT2% >> %LOG%
echo Sv opt 3: %SVOPT3% >> %LOG%
%PROSV% %DBNAME% %SVOPT1% %SVOPT2% %SVOPT3%
rem >> %LOG
echo. >> %LOG%

echo Starting bi writer ... >> %LOG%
%PROBIW% %DBNAME% -C biw %BIWOPT1%
rem  >> %LOG%

echo Starting page writer ... >> %LOG%
%PROAPW% %DBNAME% -C apw %APWOPT1%

rem load the dictionary entries
echo Loading table definitions ... >> %LOG%
%PROCL% %DBNAME% %CLNOPT1% -p create.p

rem Load the data
echo Loading %DBNAME% data using load.p ... >> %LOG%
echo This will take awhile ... >> %LOG%

rem start the loader programs
set LOADER=1
:loader
if %LOADER% GTR %NUMLOADERS% goto leaveload
echo Starting loader %LOADER% in background ... >> %LOG%
start /d%CURDIR% /min /high /b %PROCL% %DBNAME% %LDROPT1% -p load.p
set /a LOADER=%LOADER% + 1
goto loader

:leaveload

echo Database loading will continue in the background...
echo Check the log files (build*.log) to see when it is complete.
echo When completed, shutdown the database using stopatm.
goto end

:nodlc
echo You must first set DLC!
goto end

:dbrunning
echo Found a %DBNAME%.lk. Server running?
echo Exiting in disgrace.
goto end

:dbexists
echo You already have a %DBNAME%.db.
echo Exiting in disgrace.
goto end

:nost
echo There is no %DBNAME%.st.
echo Exiting in disgrace.
goto end

:end
rem Cleanup before exiting
set CURDIR=
set LOADER=
set PROPATH=
set DBNAME=
set SCALE=
set NUMLOADERS=
set CLSZ=
set BIBSZ=
set LOG=
set HISTORY=
set SUMMARY=
set EMPTYDB=
set UTILBIN=
set PROUTIL=
set PROCOPY=
set PROSTRCT=
set EXEBIN=
set PROSV=
set PROCL=
set PROAPW=
set PROBIW=
set PROAIW=
set SVOPT1=
set SVOPT2=
set SVOPT3=
set CLNOPT1=
set LDROPT1=
