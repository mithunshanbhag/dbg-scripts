@REM ***********************************************************************************************************************
@REM USAGE: This batch file will be used to install/uninstall app-verifier. It can also be used in conjunction with the 
@REM rolling system. In your rolling client's ini file, set the following:
@REM 
@REM  _DBVT_CONFIG_CUSTOM_SCRIPT_PRE_RUN_TESTS=\\clrbuckets\public\InstallAppVerifier.bat install 
@REM  _DBVT_CONFIG_CUSTOM_SCRIPT_POST_RUN_TESTS=\\clrbuckets\public\InstallAppVerifier.bat uninstall 
@REM
@REM The rolling system will accordingly invoke this script as follows:
@REM  - InstallAppVerifier.bat install (before starting any of the tests)
@REM  - InstallAppVerifier.bat uninstall (after all the tests have completed)
@REM
@REM
@REM NOTE: You cannot install 32-bit App-Verifier on a 64-bit machine even if running in WOW64 mode. According to 
@REM App-Verifier's install guide, in such cases, we should install the 64-bit version of app-verifier, which also installs  
@REM the 32-bit version behind the scenes.
@REM
@REM
@REM NOTE: If you are running this script manually on Vista+ OSes, please ensure that you are executing it from an elevated 
@REM window.
@REM ***********************************************************************************************************************

@if /I "%_echo%" == "" echo off

SETLOCAL ENABLEEXTENSIONS

set EXITCODE=
set ACTION=
set MSI_LOCATION=


@REM ------------------------------------------------------------
@REM If invalid args have been specified, then simply display the 
@REM cmd file usage and exit.
@REM ------------------------------------------------------------
if /I "%1" == "install" (
    set ACTION=/i
) else (
    if /I "%1" == "uninstall" (
        set ACTION=/x
    ) else (
        set EXITCODE=-1
        goto :_SHOW_USAGE_AND_EXIT
    )   
)


@REM --------------------------------------------------------------------------------
@REM Now depending on the user's request, we either install or uninstall app-verifier
@REM --------------------------------------------------------------------------------
if defined PROCESSOR_ARCHITEW6432 (
    set MSI_LOCATION=%~dps0appverifier\%PROCESSOR_ARCHITEW6432%\ApplicationVerifier.msi
) else (
    set MSI_LOCATION=%~dps0appverifier\%PROCESSOR_ARCHITECTURE%\ApplicationVerifier.msi
)

echo start /wait msiexec %ACTION% %MSI_LOCATION% /q /l "%TEMP%\avrfsetup.log"
start /wait msiexec %ACTION% %MSI_LOCATION% /q /l "%TEMP%\avrfsetup.log"
set EXITCODE=%ERRORLEVEL%


@REM ---------------------------
@REM Set the exit code and leave
@REM ---------------------------
:_EXIT
echo Exiting with %EXITCODE%
EXIT /B %EXITCODE%


@REM -----------------
@REM Script file usage
@REM -----------------
:_SHOW_USAGE_AND_EXIT
echo.
echo - USAGE ----------------------- USAGE ----------------------- USAGE -
echo.
echo -       InstallAppVerifier.bat [install ^| uninstall] 
echo.
echo - USAGE ----------------------- USAGE ----------------------- USAGE -
echo.
goto :_EXIT
