@REM ************************************************************************************
@REM USAGE: This batch file will launch adplus to grab process dumps at
@REM periodic intervals. The cmd line usage is as follows - 
@REM
@REM  serialdumper.bat ^<program^> ^<args to program^>
@REM  serialdumper.bat -p ^<process id^>
@REM  serialdumper.bat -pn ^<process name^>
@REM  serialdumper.bat -cleanup
@REM
@REM
@REM NOTE: @TODO - Bitness
@REM
@REM NOTE: This script will not install adplus, cdb or any of the debugging tools for you. 
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
@REM set DEBUGGERS_LOCATION=\\bvtsrv2\cortest\mithuns\dbg\%PROCESSOR_ARCHITECTURE%
set DEBUGGERS_LOCATION=c:\tools\dbg\
set DUMP_LOCATION="%TEMP%\SERIALDUMPS"
set CONFIG_FILE="%cd%\adplus_config.xml"

set ADPLUS=%DEBUGGERS_LOCATION%\adplus.vbs
set ADPLUS_ARGS=-c %CONFIG_FILE% -o %DUMP_LOCATION%


@REM ------------------------------------------------------------
@REM If invalid args have been specified, then simply display the 
@REM program usage and exit.
@REM ------------------------------------------------------------
if /I "%1" == "" (
    set EXITCODE=-1
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

if /I "%1" == "-cleanup" (
    goto :_CLEANUP_AND_EXIT
) 

@REM ---------------------------------------------------------------------------------
@REM Now depending on the options specified by the user, tweak adplus args to either 
@REM launch the application or attach to it. 
@REM ---------------------------------------------------------------------------------
if defined PROCESS_ID (
    set ADPLUS_ARGS=%ADPLUS_ARGS% -p %PROCESS_ID% 
) else (
    if defined PROCESS_NAME (
        set ADPLUS_ARGS=%ADPLUS_ARGS% -pn %PROCESS_NAME% 
  )
)


@REM -----------------------------------------------------------------------
@REM Create the ADPlus config file (over-write any existing ones if needed).
@REM We are setting up ADPlus to run in HANG mode. Please do not modify any 
@REM of these settings. 
@REM -----------------------------------------------------------------------
echo ^<ADPlus^>                                                                                > %CONFIG_FILE%
echo    ^<Settings^>                                                                          >> %CONFIG_FILE%
echo        ^<!-- defining basic settings (run mode, quiet mode, etc.) --^>                   >> %CONFIG_FILE%
echo        ^<RunMode^> HANG ^</RunMode^>                                                     >> %CONFIG_FILE%
echo        ^<AttachInterval^> 1 ^</AttachInterval^>                                          >> %CONFIG_FILE%
echo        ^<AttachRepeats^> 25 ^</AttachRepeats^>                                           >> %CONFIG_FILE%
echo        ^<Sympath^> SRV*%TEMP%*\\symbols\symbols ^</Sympath^>                             >> %CONFIG_FILE%
echo        ^<Option^> Quiet ^</Option^>                                                      >> %CONFIG_FILE%
echo    ^</Settings^>                                                                         >> %CONFIG_FILE%
echo    ^<PreCommands^>                                                                       >> %CONFIG_FILE%
echo        ^<!-- defines a set of commands to execute before the sxe and bp commands --^>    >> %CONFIG_FILE%
echo        ^<Cmd^> .loadby sos clr ^</Cmd^>                                                  >> %CONFIG_FILE%
echo    ^</PreCommands^>                                                                      >> %CONFIG_FILE%
echo    ^<PostCommands^>                                                                      >> %CONFIG_FILE%
echo        ^<!-- defines a set of commands to execute after the sxe and bp commands --^>     >> %CONFIG_FILE%
echo    ^</PostCommands^>                                                                     >> %CONFIG_FILE%
echo    ^<Exceptions^>                                                                        >> %CONFIG_FILE%
echo        ^<!-- commands acting on the exception actions --^>                               >> %CONFIG_FILE%
echo    ^</Exceptions^>                                                                       >> %CONFIG_FILE%
echo    ^<BreakPoints^>                                                                       >> %CONFIG_FILE%
echo        ^<!-- defining breakpoints --^>                                                   >> %CONFIG_FILE%
echo    ^</BreakPoints^>                                                                      >> %CONFIG_FILE%
echo    ^<HangActions^>                                                                       >> %CONFIG_FILE%
echo        ^<!-- defining actions for hang mode --^>                                         >> %CONFIG_FILE%
echo        ^<Option^> MiniDump ^</Option^>                                                   >> %CONFIG_FILE%
echo    ^</HangActions^>                                                                      >> %CONFIG_FILE%
echo ^</ADPlus^>                                                                              >> %CONFIG_FILE%

@REM ---------------------------------------------------------------------
@REM Create a new folder to store the dump files (and delete any existing)
@REM ---------------------------------------------------------------------
rd /s /q %DUMP_LOCATION%
md %DUMP_LOCATION%
if not %ERRORLEVEL% == 0 (
    set EXITCODE=%ERRORLEVEL%
    echo Error: Unable to create folder to store dumps - %DUMP_LOCATION%
    goto :_EXIT  
)

@REM ----------------------
@REM Time to run AdPlus now
@REM ----------------------
cscript %ADPLUS% %ADPLUS_ARGS% 
set EXITCODE=%ERRORLEVEL%

start explorer %DUMP_LOCATION%

@REM -------------
@REM Cleanup steps
@REM -------------
:_CLEANUP_AND_EXIT
if EXIST %CONFIG_FILE% (
    del %CONFIG_FILE%
    if not %ERRORLEVEL% == 0 (
        set EXITCODE=%ERRORLEVEL%
        echo Error: Unable to delete the config file - %CONFIG_FILE%
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
echo         serialdumper.bat ^<program^> ^<args to program^>
echo         serialdumper.bat -p ^<process id^>
echo         serialdumper.bat -pn ^<process name^>
echo         serialdumper.bat -cleanup
echo.
echo - USAGE ----------------------- USAGE ----------------------- USAGE -
echo.
goto :_EXIT

