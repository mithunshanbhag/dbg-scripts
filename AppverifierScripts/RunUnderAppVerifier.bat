@REM ************************************************************************************
@REM USAGE: This batch file will be used to launch an app-verifier run. It is meant to be
@REM used in conjunction with smarty.bat as follows - 
@REM    - smarty /Ldr RunUnderAppVerifier.bat [rest of smarty args]
@REM Smarty will in turn invoke the batch file as follows -
@REM    - RunUnderAppVerifier.bat <test exe> <test args>
@REM
@REM
@REM NOTE: Before you invoke this script, please ensure that preptests.bat has been run 
@REM and the test environment fully initialized (since the script relies of BVT_ROOT, 
@REM EXT_ROOT etc). 
@REM
@REM
@REM NOTE: This script will not install app-verifier for you. This script works 
@REM under the assumption that app-verifier has already been installed. If you need to 
@REM install app-verifier please use the following script:
@REM    - %bvt_root%\common\tools\RunUnderAppVerifier\InstallAppVerifier.bat
@REM
@REM
@REM NOTE: If you are running this script manually on Vista+ OSes, please ensure that
@REM you are executing it from an elevated window.
@REM ************************************************************************************


@if /I "%_echo%" == "" echo off

SETLOCAL ENABLEEXTENSIONS

set EXITCODE=

@REM ------------------------------------------------------------
@REM If invalid args have been specified, then simply display the 
@REM cmd file usage and exit.
@REM ------------------------------------------------------------
if /I "%1" == "" (
    set EXITCODE=-1
    echo.
    echo - USAGE ----------------------- USAGE ----------------------- USAGE -
    echo.
    echo -       RunUnderAppVerifier.bat ^<program^> ^<args to program^> 
    echo.
    echo - USAGE ----------------------- USAGE ----------------------- USAGE -
    echo.
    goto :_EXIT
)


@REM ------------------------------------------------------------------------------
@REM Make sure that we are only running executables (.exe files) under app-verifier
@REM and not batch files (.bat, .cmd) or scripts (.wsf etc).
@REM ------------------------------------------------------------------------------
if NOT "%~x1" == ".exe" (
    %*
    EXIT /B %ERRORLEVEL%
)


@REM ------------------------------------------------------------------------------------------------
@REM Now setting all appverifier related env-vars. The master settings spreadsheet is located 
@REM at: 
@REM  - %BVT_ROOT%\common\tools\RunUnderAppVerifier\Docs\AppVerifier-Settings.xlsx
@REM Please do not modify any of these settings without refering to this file. 
@REM 
@REM
@REM We are using the verification layers as shown below. The app-verifier stops for each of the 
@REM verification layers have been documented in the master settings file.
@REM  - COM       : The COM checks ensure that COM APIs are used correctly
@REM  - Exceptions: The Exception checks ensure that applications do not hide access 
@REM                violations by using structured exception handling.
@REM  - Handles   : The Handles tests ensure that an application does not attempt to use 
@REM                invalid handles.
@REM  - Heaps     : The Heap Verifier uses guard pages (or not depending on the properties 
@REM                selected) to check for memory corruption issues in the heap.
@REM  - Locks     : The Lock Verifier checks for errors (or stops) in the file lock usages. 
@REM                The primary purpose of the Locks test is to ensure that the application 
@REM                uses critical sections properly.
@REM  - Memory    : The Memory checks ensure APIs for virtual space manipulations are used 
@REM                correctly (e.g. VirtualAlloc, VirtualFree, MapViewOfFile).
@REM  - ThreadPool: The threadpool verification ensures correct usage of threadpool API’s and 
@REM                enforces consistency checks on worker-thread-states after a callback.
@REM  - TLS       : The TLS checks to ensure that Thread Local Storage APIs are used correctly.
@REM  - SRWLock	  : The slim reader/writer (SRW) lock checks ensure that applications initialize, 
@REM                acquire, and release SRW locks correctly.
@REM  - Leak      : Leak verifier is designed to catch virtual reservation, registry, handle, and 
@REM                heap leaks. Leak verifier detects leaks by tracking the resources made by a dll 
@REM                that are not freed by the time the dll was unloaded.
@REM  - LuaPriv   : The Limited User Account Privilege Predictor (LuaPriv) has two primary 
@REM                goals:
@REM                - Predictive: While running an application with administrative privilege, 
@REM                predict whether that application would work as well if run with less 
@REM                privilege (generally, as a normal user). For example, if the application 
@REM                writes to files that only allow Administrators access, then that application 
@REM                won’t be able to write to the same file if run as a non-administrator. 
@REM                - Diagnostic: When running as a non-administrator, identify potential problems 
@REM                that may already exist with the current run. Continuing the previous example, 
@REM                if the application tries to write to a file that only grants members of the 
@REM                Administrators group access, the application will get an ACCESS_DENIED error.
@REM                If the application doesn’t operate correctly, this operation may be the 
@REM                culprit. 
@REM  - DangerourAPIs : The Dangerous API Verifier tracks to see if the application is 
@REM                          using unsafe APIs (e.g. TerminateThread).
@REM  - DirtyStacks   : <TBD>
@REM  
@REM 
@REM In addition, We'll also be using the following settings -
@REM - ErrorReport=0x181 : All app-verifier stops will be recorded in the log file
@REM                       along with the stack-traces. 
@REM - Flavor=0x0        : All app-verifier stops are treated as continuable stops.
@REM
@REM
@REM Also in order to grab a stack-trace (on an app-verifier break), we need to set the symbol-path
@REM i.e. the _NT_SYMBOL_PATH variable.
@REM
@REM NOTE: The stop code 0x13 in the HEAPS_STOPS layer basically checks for occurences of first 
@REM chance AVs. Many of the CLR team's tests throw AVs on purpose. This leads to a lot of noise
@REM and unnecessary investigations. Hence we will not be enabling this particular stop (0x13).
@REM
@REM ------------------------------------------------------------------------------------------------

set APP=%~nX1
set APP_VERIFIER=%windir%\system32\appverif.exe
@REM -FUTURE- set LAYERS=COM Exceptions Handles Heaps Locks Memory Threadpool TLS LuaPriv DangerousAPIs DirtyStacks
set LAYERS=COM Exceptions Handles Heaps Locks Memory Threadpool TLS SRWLock Leak DangerousAPIs DirtyStacks
set ERRORREPORT=0x181
set FLAVOR=0x0

set COM_STOPS=0x400 0x401 0x402 0x403 0x404 0x405 0x406 0x407 0x408 0x409 0x40A 0x40B 0x40C 0x40D 0x40E 0x40F 0x410 0x413 0x414 0x415 0x416 0x417 0x418 0x419 0x41A 0x41B 0x41C 0x41D 0x41E 0x41F 0x420 0x421 0x422
set EXCEPTION_STOPS=0x650
set HANDLES_STOPS=0x300 0x301 0x302 0x303 0x304 0x305
set HEAPS_STOPS=0x1 0x2 0x3 0x4 0x5 0x6 0x7 0x8 0x9 0xA 0xB 0xC 0xD 0xE 0xF 0x10 0x11 0x12 0x14
set LOCKS_STOPS=0x200 0x201 0x202 0x203 0x204 0x205 0x206 0x207 0x208 0x209 0x210 0x211 0x212 0x213 0x214 0x215
set MEMORY_STOPS=0x600 0x601 0x602 0x603 0x604 0x605 0x606 0x607 0x608 0x609 0x60A 0x60B 0x60C 0x60D 0x60E 0x60F 0x610 0x612 0x613 0x614 0x615 0x616 0x617 0x618 0x619 0x61A 0x61B 0x61C 0x61D 0x61E
set THREADPOOL_STOPS=0x700 0x701 0x702 0x703 0x704 0x705 0x706 0x707 0x708 0x709 0x70A 0x70B 0x70C 0x70D 
set TLS_STOPS=0x350 0x351 0x352
set SRWLOCK_STOPS=0x250 0x251 0x252 0x253 0x254 0x255 0x256 0x257
set LEAK_STOPS=0x900 0x901 0x902 0x903 0x904 0x905
set LUAPRIV_STOPS=
set DANGEROUSAPIS_STOPS=
set DIRTYSTACKS_STOPS=

set _NT_SYMBOL_PATH=%BVT_ROOT%;%EXT_ROOT%;%BVT_ROOT%\common\Tools\RunUnderAppVerifier\AppVerifier\%_tgtcpu%;SRV*%TEMP%*\\symbols\symbols

set DEBUGGER_PATH=%BVT_ROOT%\common\tools\%_tgtcpu%\debuggers\cdb.exe
@REM -FUTURE- set DEBUGGER_ARGS=-g -G -cfr %BVT_ROOT%\common\tools\RunUnderAppVerifier\dbgscript.txt
set DEBUGGER_ARGS=-g -G -c ".lines;l+l;l+s;l+t;sxi ct;sxi et;sxi cpr;sxi epr;sxi ld;sxi ud;sxi ser;sxi ibp;sxi iml;sxi out;sxd av;sxi asrt;sxi aph;sxd bpe;sxi bpec;sxi eh;sxi clr;sxi clrn;sxi cce;sxi cc;sxi cce;sxi cc;sxi dm;sxi dbce;sxi gp;sxi ii;sxi ip;sxi dz;sxi iov;sxd ch;sxi hc;sxi lsq;sxi isc;sxi 3c;sxi svh;sxi sse;sxi ssec;sxi sbo;sxd sov;sxi vs;sxi vcpp;sxi wkd;sxi wob;sxi wos;sxi *;g;"


@REM ---------------------------------------------------------------
@REM Do not run pre/post commands under app-verifier. Also if we are
@REM running a pre/post commands, make sure we have a clean slate. 
@REM ---------------------------------------------------------------
if DEFINED __RelativePath (
    %APP_VERIFIER% -disable * -for *
    %*
    EXIT /B %ERRORLEVEL%
)


@REM -------------------------------------
@REM Delete any existing app-verifier logs
@REM -------------------------------------
if EXIST "%userprofile%\appverifierlogs\*%APP%*" (
    del /Q "%userprofile%\appverifierlogs\*%APP%*"
)

@REM --------------------------------------------
@REM Enable app-verifer for specified application 
@REM --------------------------------------------
%APP_VERIFIER% -enable %LAYERS% -for %APP% >nul
%APP_VERIFIER% -configure %COM_STOPS% %EXCEPTION_STOPS% %HANDLES_STOPS% %HEAPS_STOPS% %LOCKS_STOPS% %MEMORY_STOPS% %THREADPOOL_STOPS% %TLS_STOPS% %SRWLOCK_STOPS% %LEAK_STOPS% %LUAPRIV_STOPS% %DANGEROUSAPIS_STOPS% %DIRTYSTACKS_STOPS% -for %APP% -with ErrorReport=%ERRORREPORT% Flavor=%FLAVOR% >nul

if not %ERRORLEVEL% == 0 (
    set EXITCODE=%ERRORLEVEL%
    echo Error: Encountered an unexpected error while setting app-verifier options. Exiting........
    goto :_CLEANUP
)

@REM ------------------------------------------------------------------
@REM Now launch the test under the debugger. The debugger will pass the 
@REM debuggee's exit code as its own. We shall record this exit code
@REM ------------------------------------------------------------------
%DEBUGGER_PATH% %DEBUGGER_ARGS% %*
set EXITCODE=%ERRORLEVEL%


@REM --------------------------------------------------------------------
@REM If an app-verifier log was generated, we should now export it 
@REM to xml (It is possible that app-verifier does not create a log for
@REM specified app). Use a findstr query on the logs to see if there are 
@REM any app-verifier errors in it.
@REM --------------------------------------------------------------------

if NOT EXIST "%userprofile%\appverifierlogs\*%APP%*" (
    echo.
    echo ===================================================================================
    echo App-Verifier did not generate a log file for application:
    echo "%*"
    echo ===================================================================================
    echo.
    goto :_CLEANUP
)

%APP_VERIFIER% -export log -for %APP% -with to="%userprofile%\appverifierlogs\%APP%.xml"
if not %ERRORLEVEL% == 0 (
    set EXITCODE=%ERRORLEVEL%
    echo Error: Encountered an unexpected error while exporting app-verifier log to xml. Exiting........
    goto :_CLEANUP
)

findstr /i /R "<avrf:logEntry.*Severity=\"Error\">" "%userprofile%\appverifierlogs\%APP%.xml" >nul
echo.
echo ===================================================================================
if %ERRORLEVEL% == 0 (
    set EXITCODE=-1
    echo Error: App-verifier errors were detected. 
) else (
    echo No App-verifier errors were detected.
)
echo App-Verifer log for "%*"
echo ===================================================================================
echo.
type "%userprofile%\appverifierlogs\%APP%.xml"
echo.
echo.


@REM -------------
@REM Cleanup steps
@REM -------------
:_CLEANUP
%APP_VERIFIER% -disable %LAYERS% -for %APP% >nul
%APP_VERIFIER% -delete settings -for %APP% >nul 
if EXIST "%userprofile%\appverifierlogs\*%APP%*" (
    del /Q "%userprofile%\appverifierlogs\*%APP%*"
)


@REM ---------------------------
@REM Set the exit code and leave
@REM ---------------------------
:_EXIT
echo Exiting with %EXITCODE%
EXIT /B %EXITCODE%




