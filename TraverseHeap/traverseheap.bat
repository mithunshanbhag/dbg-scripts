@REM ************************************************************************************
@REM USAGE: This batch file will do the following - 
@REM - launch use cdb to attach to a specified process
@REM - grab the output of !traverseheap command (xml file) 
@REM - timestamp the file 
@REM - push it to %temp%\dumps\.
@REM
@REM The cmd line usage is as follows - 
@REM    traverseheap.bat -p ^<process id^>
@REM    traverseheap.bat -pn ^<process name^>
@REM
@REM
@REM NOTE: @TODO - Bitness
@REM
@REM NOTE: By default this script assumes that we are attaching to a CLR v4 processs.
@REM If that is not the case (i.e. we are using V2 process), then change the following
@REM line in the script - ".loadby sos clr" to ".loadby sos mscorwks".
@REM
@REM NOTE: This script will not install cdb or any of the debugging tools for you. 
@REM This script works under the assumption that the debuggers and other support tools 
@REM have already been installed. 
@REM
@REM NOTE: If you are running this script manually on Vista+ OSes, please ensure that
@REM you are executing it from an elevated window.
@REM ************************************************************************************


@if /I "%_echo%" == "" echo off

SETLOCAL ENABLEEXTENSIONS

set EXITCODE=0
Set PROCESS_ID=
set PROCESS_NAME=

@REM @todo change this later
set DUMP_LOCATION="%TEMP%\DUMPS"
set DEBUGGER_PATH="%ProgramFiles(x86)%\Windows Kits\10\Debuggers\x64\cdb.exe"
set DEBUGGER_SCRIPT=cdbscript.txt 
set DEBUGGER_ARGS=-cf %DEBUGGER_SCRIPT%



@REM ------------------------------------------------------------
@REM If invalid args have been specified, then simply display the 
@REM program usage and exit.
@REM ------------------------------------------------------------
if /I "%1" == "" (
    goto :_USAGE
)
if /I "%1" == "?" (
    goto :_USAGE
)
if /I "%1" == "/?" (
    goto :_USAGE
)
if /I "%1" == "-?" (
    goto :_USAGE
)
if /I "%1" == "/help" (
    goto :_USAGE
)


if /I "%1" == "-p" (
    if /I "%2" == "" (
        set EXITCODE=-1
        goto :_USAGE    
    )    
    set PROCESS_ID=%2
) 

if /I "%1" == "-pn" (
    if /I "%2" == "" (
        set EXITCODE=-1
        goto :_USAGE    
    )    
    set PROCESS_NAME=%2
) 

@REM ---------------------------------------------------------------------------------
@REM Now depending on the options specified by the user, tweak adplus args to either 
@REM launch the application or attach to it. 
@REM ---------------------------------------------------------------------------------
if defined PROCESS_ID (
    set DEBUGGER_ARGS=%DEBUGGER_ARGS% -p %PROCESS_ID% 
) else (
    if defined PROCESS_NAME (
        set DEBUGGER_ARGS=%DEBUGGER_ARGS% -pn %PROCESS_NAME% 
  )
)

@REM -----------------------------------------------------------------------
@REM Create the ADPlus config file (over-write any existing ones if needed).
@REM We are setting up ADPlus to run in HANG mode. Please do not modify any 
@REM of these settings. 
@REM -----------------------------------------------------------------------

echo .symfix %TEMP%\symbols;                         > %DEBUGGER_SCRIPT%
echo .loadby sos clr;                                >> %DEBUGGER_SCRIPT%
echo !traverseheap -xml heap.xml;                    >> %DEBUGGER_SCRIPT%
echo .detach;                                        >> %DEBUGGER_SCRIPT%
echo q;                                              >> %DEBUGGER_SCRIPT%

@REM ----------------------------
@REM Time to run the debugger now
@REM ----------------------------
%DEBUGGER_PATH% %DEBUGGER_ARGS% 
set EXITCODE=%ERRORLEVEL%
if not %ERRORLEVEL% == 0 (
    set EXITCODE=%ERRORLEVEL%
    echo An error occurred while grabbing the process dump. 
    goto :_EXIT  
)

@REM ----------------------------------------------------------------------
@REM grab the XML file (traverseheap output), timestamp it and push it to 
@REM the location - %DUMP_LOCATION%
@REM ----------------------------------------------------------------------
md %DUMP_LOCATION% >nul

set cur_yyyy=%date:~10,4%
set cur_mm=%date:~4,2%
set cur_dd=%date:~7,2%

set cur_hh=%time:~0,2%
if %cur_hh% lss 10 (
  set cur_hh=0%time:~1,1%
)
set cur_nn=%time:~3,2%
set cur_ss=%time:~6,2%
set cur_ms=%time:~9,2%

set timestamp=%cur_yyyy%%cur_mm%%cur_dd%-%cur_hh%%cur_nn%%cur_ss%%cur_ms%

move heap.xml %DUMP_LOCATION%\%timestamp%-heap.xml

set cur_yyyy=
set cur_mm=
set cur_dd=
set cur_hh=
set cur_nn=
set cur_ss=
set cur_ms=
set timestamp=


@REM -------------
@REM Cleanup steps
@REM -------------
if EXIST %DEBUGGER_SCRIPT% (
    del %DEBUGGER_SCRIPT%
    if not %ERRORLEVEL% == 0 (
        set EXITCODE=%ERRORLEVEL%
        echo Error: Unable to delete the debugger script- %DEBUGGER_SCRIPT%
        goto :_EXIT  
    )
)

@REM ---------------------------
@REM Set the exit code and leave
@REM ---------------------------
:_EXIT
echo Exiting with %EXITCODE%
EXIT /B %EXITCODE%

@REM -------------
@REM program usage
@REM -------------
:_USAGE
echo.
echo - USAGE ----------------------- USAGE ----------------------- USAGE -
echo.
echo         dumpproc.bat -p ^<process id^>
echo         dumpproc.bat -pn ^<process name^>
echo.
echo - USAGE ----------------------- USAGE ----------------------- USAGE -
echo.
goto :_EXIT

