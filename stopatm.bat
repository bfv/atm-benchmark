@echo off
rem ATM performance test:
rem Shutdown ATM database
rem 21-Sep-95 ghb
rem 11-Apr-02 tku

type version.txt
if not defined DLC goto nodlc
"%DLC%\bin\_mprshut" atm -by
goto end

:nodlc
echo You must first set DLC!
goto end

:end
