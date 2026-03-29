@REM ******************************************************************************
@REM DESCRIPTION
@REM ===========
@REM This batch file creates two cdb scripts (scriptdbg.txt, scriptbp.txt) that
@REM facilitate recording of CLR API usage under any customer scenario. The list 
@REM of APIs (and breakpoints) is obtained from the APIs.csv file (located in the
@REM same folder as this script).
@REM
@REM USAGE
@REM =====
@REM For usage options, please scroll down to the very end of this file.
@REM 
@REM NOTES
@REM =====
@REM 1. You might be required to run this batch file as an elevated admin.
@REM 
@REM PLANNED MODIFICATIONS / BUG-FIXES 
@REM =================================
@REM 1. For the cdb scripts to work we'd need private symbols (this is required
@REM    for the breakpoints to bind). This may limit the possibility of external 
@REM    consumption (when private symbols aren't available). However there "may" 
@REM    exist a work-around - we can investigate the possibility of collecting 
@REM    IDNA traces and then run these scripts on the IDNA trace (offline) 
@REM    instead of the live process/app.
@REM 2. The /noisy switch should be used by itself. Else it will create empty
@REM    cdb scripts. We need to have an explicit check for this.
@REM ******************************************************************************

@if /I "%_echo%" == "" echo off

SETLOCAL ENABLEEXTENSIONS

set EXITCODE=0

set APIS_CSV_FILE=%~dp0\APIs.csv
set RAW_TRACE_OUTPUT=trace.raw
set DEBUGGER_SCRIPT=scriptDbg.txt
set BREAKPOINT_SCRIPT=scriptBP.txt

echo.

@REM ----------------------------------------------------------------
@REM Display the usage/help screen under the following conditions - 
@REM - No args specified on the cmd line
@REM - User requests for help (-?, /?, ? switches on cmd line).
@REM - An invalid arg is specified on the cmd line.
@REM ----------------------------------------------------------------

if /I "%1" == "" (
  set EXITCODE=1
  goto :_USAGE      
)
if /I "%1" == "/?"  goto :_USAGE      
if /I "%1" == "-?"  goto :_USAGE
if /I "%1" == "?"   goto :_USAGE


@REM ------------------------------------
@REM Scan the args specified by the user. 
@REM ------------------------------------

FOR %%a IN (%*) DO (
    if /I "%%a" == "/dbg" (
      set TRACE_DEBUGGING_APIS=1
    ) else (
        if /I "%%a" == "/prf" (
          set TRACE_PROFILING_APIS=1
        ) else (
            if /I "%%a" == "/sym" (
              set TRACE_SYMBOL_APIS=1
            ) else (
                if /I "%%a" == "/metadata" (
                  set TRACE_METADATA_APIS=1
                ) else (
                    if /I "%%a" == "/hosting" (
                      set TRACE_HOSTING_APIS=1
                    ) else (
                        if /I "%%a" == "/noisy" (
                          set ENABLE_NOISY_APIS=1
                        ) else (
                            echo Error: Invalid arg specified - "%%a"
                            set EXITCODE=1
                            goto :_USAGE
                        )
                    )
                )
            )
        )
    )
)

@REM ----------------------------------------------------------------
@REM Pre-condition check to see if the APIs.csv file actually exists. 
@REM ----------------------------------------------------------------

if NOT EXIST %APIS_CSV_FILE% (
    set EXITCODE = 1
    echo Error: Unable to locate file - %APIS_CSV_FILE%.
    echo.
    goto :_EXIT
)


@REM -----------------------------------------------------------------------
@REM Create the main cdb script (over-write any existing ones if needed).
@REM This cdb script will set delayed (unresolved) breakpoints. Please do  
@REM not modify any of these settings.
@REM -----------------------------------------------------------------------

echo Creating CDB scripts...
echo.

echo ******************************************************      > %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * DESCRIPTION (scriptdbg.txt)                              >> %DEBUGGER_SCRIPT%
echo * ===========================                              >> %DEBUGGER_SCRIPT%
echo * This script does the following:                          >> %DEBUGGER_SCRIPT%
echo * -  Changes the exception filter to break-in if a         >> %DEBUGGER_SCRIPT%
echo *    child process is created. This script is then         >> %DEBUGGER_SCRIPT%
echo *    executed for the child process too.                   >> %DEBUGGER_SCRIPT%
echo * -  Disables first-chance exception/AVs from breaking     >> %DEBUGGER_SCRIPT%
echo *    into the debugger.                                    >> %DEBUGGER_SCRIPT%
echo * -  Sets delayed (unresolved) breakpoints on the APIs     >> %DEBUGGER_SCRIPT%
echo *    obtained from the APIs.csv file. In the command       >> %DEBUGGER_SCRIPT%
echo *    string for these BPs, it specifies another cdb        >> %DEBUGGER_SCRIPT%
echo *    script (scriptBP.txt). That script is run every       >> %DEBUGGER_SCRIPT%
echo *    time a BP is hit.                                     >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * USAGE (scriptdbg.txt)                                    >> %DEBUGGER_SCRIPT%
echo * =====================                                    >> %DEBUGGER_SCRIPT%
echo * cdb -cf "scriptdbg.txt" -G -o [filename]                 >> %DEBUGGER_SCRIPT%
echo * cdb -cf "scriptdbg.txt" -G -o -p [process id]            >> %DEBUGGER_SCRIPT%
echo * cdb -cf "scriptdbg.txt" -G -o -pn [process name]         >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * NOTES (scriptdbg.txt)                                    >> %DEBUGGER_SCRIPT%
echo * =====================                                    >> %DEBUGGER_SCRIPT%
echo * 1. This cdb script cannot be directly used to record     >> %DEBUGGER_SCRIPT%
echo *    API usage in a debuggee process (in a managed         >> %DEBUGGER_SCRIPT%
echo *    debugging scenario) since we cannot invasively        >> %DEBUGGER_SCRIPT%
echo *    attach cdb to the a process that is already under     >> %DEBUGGER_SCRIPT%
echo *    a native debugger.                                    >> %DEBUGGER_SCRIPT%
echo *    As a workaround, you can disable the VS Hosting       >> %DEBUGGER_SCRIPT%
echo *    process (vshost.exe) via the VS IDE. Then you         >> %DEBUGGER_SCRIPT%
echo *    can use this script without the "-o" option (i.e.     >> %DEBUGGER_SCRIPT%
echo *    no child process debugging). In then you can at       >> %DEBUGGER_SCRIPT%
echo *    least get API usage info for the DBI/DAC (RS).        >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo ******************************************************     >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * DESCRIPTION (scriptBP.txt)                               >> %DEBUGGER_SCRIPT%
echo * ==========================                               >> %DEBUGGER_SCRIPT%
echo * This is the companion script to scriptdbg.txt. This      >> %DEBUGGER_SCRIPT%
echo * script defines actions when the breakpoints are          >> %DEBUGGER_SCRIPT%
echo * triggered. Currently those actions are -                 >> %DEBUGGER_SCRIPT%
echo *  - printing the active process-id, thread-id             >> %DEBUGGER_SCRIPT%
echo *  - printing the currently active frame                   >> %DEBUGGER_SCRIPT%
echo *  - printing the local variables                          >> %DEBUGGER_SCRIPT%
echo *  - dumping the call-stack.                               >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * Please do not modify this cdb script.                    >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * USAGE (scriptBP.txt)                                     >> %DEBUGGER_SCRIPT%
echo * ====================                                     >> %DEBUGGER_SCRIPT%
echo * This cdb script is indirectly invoked by the             >> %DEBUGGER_SCRIPT%
echo * scriptdbg.txt script.                                    >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo * NOTES (scriptBP.txt)                                     >> %DEBUGGER_SCRIPT%
echo * ====================                                     >> %DEBUGGER_SCRIPT%
echo * 1. We havce currently disabled (commented out) the       >> %DEBUGGER_SCRIPT%
echo *    "dv" and "k" commands. We'll re-enable them in        >> %DEBUGGER_SCRIPT%
echo *    the future.                                           >> %DEBUGGER_SCRIPT%
echo *                                                          >> %DEBUGGER_SCRIPT%
echo ******************************************************     >> %DEBUGGER_SCRIPT%

echo sxe -c "$<%DEBUGGER_SCRIPT%" ibp                           >> %DEBUGGER_SCRIPT%  
echo sxd av                                                     >> %DEBUGGER_SCRIPT%
echo sxd asrt                                                   >> %DEBUGGER_SCRIPT%
echo sxd aph                                                    >> %DEBUGGER_SCRIPT%
echo sxd bpe                                                    >> %DEBUGGER_SCRIPT%
echo sxd bpec                                                   >> %DEBUGGER_SCRIPT%
echo sxd eh                                                     >> %DEBUGGER_SCRIPT%
echo sxd clr                                                    >> %DEBUGGER_SCRIPT%
echo sxd clrn                                                   >> %DEBUGGER_SCRIPT%
echo sxd cce                                                    >> %DEBUGGER_SCRIPT%
echo sxd cc                                                     >> %DEBUGGER_SCRIPT%
echo sxd dm                                                     >> %DEBUGGER_SCRIPT%
echo sxd gp                                                     >> %DEBUGGER_SCRIPT%
echo sxd ii                                                     >> %DEBUGGER_SCRIPT%
echo sxd ip                                                     >> %DEBUGGER_SCRIPT%
echo sxd dz                                                     >> %DEBUGGER_SCRIPT%
echo sxd iov                                                    >> %DEBUGGER_SCRIPT%
echo sxd ch                                                     >> %DEBUGGER_SCRIPT%
echo sxd hc                                                     >> %DEBUGGER_SCRIPT%
echo sxd lsq                                                    >> %DEBUGGER_SCRIPT%
echo sxd isc                                                    >> %DEBUGGER_SCRIPT%
echo sxd svh                                                    >> %DEBUGGER_SCRIPT%
echo sxd sse                                                    >> %DEBUGGER_SCRIPT%
echo sxd ssec                                                   >> %DEBUGGER_SCRIPT%
echo sxd sbo                                                    >> %DEBUGGER_SCRIPT%
echo sxd sov                                                    >> %DEBUGGER_SCRIPT%
echo sxd vs                                                     >> %DEBUGGER_SCRIPT%
echo sxd wkd                                                    >> %DEBUGGER_SCRIPT%
echo sxd wob                                                    >> %DEBUGGER_SCRIPT%
echo sxd wos                                                    >> %DEBUGGER_SCRIPT%
echo .sympath+ SRV*%TEMP%*\\symbols\symbols;                    >> %DEBUGGER_SCRIPT%
echo .lines -d                                                  >> %DEBUGGER_SCRIPT%
echo l+l                                                        >> %DEBUGGER_SCRIPT%
echo l+s                                                        >> %DEBUGGER_SCRIPT%
echo l+t                                                        >> %DEBUGGER_SCRIPT%  
echo .reload /f                                                 >> %DEBUGGER_SCRIPT%

for /F "skip=1 eol=0 delims=, tokens=2,3,4,5,6" %%i in (%APIS_CSV_FILE%) do (

  if /I "%%j"=="dbg" (
    if defined TRACE_DEBUGGING_APIS (
      if /I "%%k" == "1" (
        if defined ENABLE_NOISY_APIS (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
        )
      ) else (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
      )
    )
  )
  if /I "%%j"=="prf" (  
    if defined TRACE_PROFILING_APIS (
      if /I "%%k" == "1" (
        if defined ENABLE_NOISY_APIS (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
        )
      ) else (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
      )
    )
  )
  if /I "%%j"=="sym" (
    if defined TRACE_SYMBOL_APIS (
      if /I "%%k" == "1" (
        if defined ENABLE_NOISY_APIS (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
        )
      ) else (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
      )
    )
  )
  if /I "%%j"=="metadata" (  
    if defined TRACE_METADATA_APIS (
      if /I "%%k" == "1" (
        if defined ENABLE_NOISY_APIS (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
        )
      ) else (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
      )
    )
  )
  if /I "%%j"=="hosting" (  
    if defined TRACE_HOSTING_APIS (
      if /I "%%k" == "1" (
        if defined ENABLE_NOISY_APIS (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
        )
      ) else (
          echo bu %%m "$$>a<%BREAKPOINT_SCRIPT% %%i"            >> %DEBUGGER_SCRIPT%
      )
    )
  )
)

echo g                                                          >> %DEBUGGER_SCRIPT%


@REM -----------------------------------------------------------------------
@REM Also create the companion script (over-write any existing ones if
@REM needed).
@REM -----------------------------------------------------------------------

echo .foreach (var {.logappend "%RAW_TRACE_OUTPUT%";}) {.break;}     > %BREAKPOINT_SCRIPT% 
echo .printf "-event-\n"                                            >> %BREAKPOINT_SCRIPT%
echo .foreach /pS 3 (var {~#}) {.printf "${var} "; .break;}         >> %BREAKPOINT_SCRIPT%
echo .foreach /pS 3 (var {.frame}) {.printf "${var} "; .break;}     >> %BREAKPOINT_SCRIPT%
echo .printf "${$arg1}\n"                                           >> %BREAKPOINT_SCRIPT%
@REM echo .printf "-locals-\n"                                          >> %BREAKPOINT_SCRIPT%
@REM echo dv /V /i /t                                                   >> %BREAKPOINT_SCRIPT%
@REM echo .printf "-stack-\n"                                           >> %BREAKPOINT_SCRIPT%
@REM echo k 3000                                                        >> %BREAKPOINT_SCRIPT%
@REM echo .printf "-endstack-\n"                                        >> %BREAKPOINT_SCRIPT%
@REM echo .printf "\n"                                                  >> %BREAKPOINT_SCRIPT%
echo .foreach (var {.logclose;}) {.break;}                          >> %BREAKPOINT_SCRIPT%
echo g                                                              >> %BREAKPOINT_SCRIPT%


@REM -------------------------------------------
@REM Check if cdb scripts were actually created.
@REM -------------------------------------------

if NOT EXIST %DEBUGGER_SCRIPT% (
    set EXITCODE = 1
    echo Error: Unable to create CDB script - %DEBUGGER_SCRIPT%
    echo Are you sure you're running as elevated admin?
    echo.
    goto :_EXIT
)
if NOT EXIST %BREAKPOINT_SCRIPT% (
    set EXITCODE = 1
    echo Error: Unable to create CDB script - %BREAKPOINT_SCRIPT%
    echo Are you sure you're running as elevated admin?
    echo.
    goto :_EXIT
)

echo CDB scripts created:
echo - %DEBUGGER_SCRIPT%
echo - %BREAKPOINT_SCRIPT%
echo.


@REM ----------------------------
@REM Set the exit code and leave.
@REM ----------------------------

:_EXIT
echo Exiting with %EXITCODE%
echo.
EXIT /B %EXITCODE%


@REM ------------------------
@REM Display the help screen.
@REM ------------------------

:_USAGE
echo.
echo - USAGE ---------------------------- USAGE ---------------------------- USAGE -
echo.
echo         CreateCDBScripts.bat [option [options]...] [/noisy]
echo.
echo         Multiple options can be combined. The valid options are - 
echo            /dbg      : Enables recording of debugging (ICorDebug*) APIs.
echo            /prf      : Enables recording of profiling (ICorProfiler*) APIs.
echo            /sym      : Enables recording of symbol-store APIs.
echo            /metadata : Enables recording of Metadata APIs.
echo            /hosting  : Enables recording of hosting APIs.
echo 
echo          Option for 'noisy' APIs
echo            /noisy    : Enables recording of frequently used APIs (by default
echo                        'noisy' APIs are not recorded).    
echo.
echo        Example: To enable recording of debugging and profiling APIs, this
echo        batch file must be called as follows: "CreateCDBScripts /dbg /prf"
echo.        
echo        This script file creates two cdb scripts (scriptdbg.txt, scriptbp.txt)
echo        in the same folder from which it is called. Please ensure that you
echo        are running this script as an elevated admin.  
echo.
echo - USAGE ---------------------------- USAGE ---------------------------- USAGE -
echo.
goto :_EXIT