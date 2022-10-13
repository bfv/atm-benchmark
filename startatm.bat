@echo off
rem ATM performance test:
rem Start ATM database
rem 21-Sep-95 ghb
rem 11-Apr-02 tku

type version.txt
if not defined DLC goto nodlc
"%DLC%\bin\_mprosrv" atm -pf trnsactn.pf
"%DLC%\bin\_mprshut" atm -C apw
"%DLC%\bin\_mprshut" atm -C biw
call go.bat
goto end

:nodlc
echo You must first set DLC!
goto end

:end
