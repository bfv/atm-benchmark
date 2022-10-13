@echo off
rem ATM performanc test:
rem start a new test run
rem 21-Sep-95 ghb
rem 11-Apr-02 tku

type version.txt
set CURDIR=C:\PROGRESS\CLASS\ATM
set PROPATH=%CURDIR%
if not defined DLC goto nodlc

set DBNAME=atm
set DRIVER=drivernt.p
set RUNLOG=lastrun.log
set TEMPLOG=temp.log
set STARTLOG=startup.log
set HISTORY=allruns.log
set SUMMARY=summary.log

rem Take executables from here
set DLCBIN=%DLC%\bin
set PROSV=%DLCBIN%\_mprosrv
set PROCL=%DLCBIN%\_progres
set PROAPW=%DLCBIN%\_mprshut
set PROBIW=%DLCBIN%\_mprshut
set PROAIW=%DLCBIN%\_mprshut

rem Writer processes
set NUMAPW=0
set BIW=no
set AIW=no

rem Server options
set SVOPT1=-n 20 -L 512
rem set SVOPT2=-B 5000
rem set SVOPT3=-bibufs 20

rem Client options
set CLOPT=-l 5
set DOCLIENT=%PROCL% %DBNAME% -b -rand 2
set DODRIVER=%PROCL% %DBNAME% -b -rand 2 -p %DRIVER%

rem Start the test
if not exist %DBNAME%.db goto nodb
echo Using database %DBNAME%.

if exist %DBNAME%.lk goto startdriver

rem Need to start database
echo Starting %DBNAME% database using %PROSV%, but first
echo we pause in case you forgot something...
pause
del client*.log

rem Log a few things
echo Logging startup to %STARTLOG% and %RUNLOG%.
type version.txt > %STARTLOG%
(date /t & time /t) >> %STARTLOG%
echo Machine name %COMPUTERNAME% >> %STARTLOG%
echo Modules: >> %STARTLOG%
echo %PROSV% >> %STARTLOG%
echo %PROCL% >> %STARTLOG%
echo %PROAPW% >> %STARTLOG%
echo Server options: >> %STARTLOG%
echo sv opt 1: %SVOPT1% >> %STARTLOG%
echo sv opt 2: %SVOPT2% >> %STARTLOG%
echo sv opt 3: %SVOPT3% >> %STARTLOG%
echo Page cleaners: %NUMAPW%, BI writer: %BIW%, AI writer: %AIW% >> %STARTLOG%
echo. >> %STARTLOG%
type %STARTLOG% > %RUNLOG%
echo. >> %SUMMARY%
type %STARTLOG% >> %SUMMARY%

rem Start server
echo Start %DBNAME% database ...
%PROSV% %DBNAME% %SVOPT1% %SVOPT2% %SVOPT3%

rem Start before image writer
if not %BIW%==yes goto runaiw

echo Start before image writer ...
%PROBIW% %DBNAME% -C biw

:runaiw
rem Start after image writer
if not %AIW%==yes goto runapw

echo Start after image writer ...
%PROAIW% %DBNAME% -C aiw

:runapw
rem Start page cleaners (try 1 per db disk + 1 extra)
set APW=1

:apwcnt
if %APW% GTR %NUMAPW% goto leaverunapw
echo Start page writer %APW% ...
%PROAPW% %DBNAME% -C apw
set /a APW=%APW% + 1
goto apwcnt

:leaverunapw

(date /t & time /t) >> %RUNLOG%
echo Database %DBNAME% should now be running.
echo Type go again to start the test driver.
goto end

:startdriver
rem Start driver now
echo %DBNAME% database is up.
echo Starting test driver %DRIVER%, but first
echo we pause in case you forgot something...
pause
echo Results will be written to %RUNLOG%.
(date /t & time /t) > %TEMPLOG%
echo. >> %TEMPLOG%
(date /t & time /t) >> %RUNLOG%
start /d%CURDIR% /min /high /b %DODRIVER%
echo The test has been started in the background.
echo Check %RUNLOG% to find out when it has finished.
goto end

:nodlc
echo You must first set DLC!
goto end

:nodb
echo There is no database called %DBNAME%.
echo Exiting in disgrace.
goto end

:end
rem Cleanup before exiting
set CURDIR=
set PROPATH=
set DBNAME=
set DRIVER=
set RUNLOG=
set TEMPLOG=
set STARTLOG=
set HISTORY=
set SUMMARY=
set DLCBIN=
set PROSV=
set PROCL=
set PROAPW=
set PROBIW=
set PROAIW=
set NUMAPW=
set BIW=
set AIW=
set SVOPT1=
set SVOPT2=
set SVOPT3=
set CLOPT=
set DOCLIENT=
set DODRIVER=
set APW=
