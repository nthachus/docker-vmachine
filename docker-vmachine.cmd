@ECHO OFF
SetLocal

IF DEFINED DOCKER_MACHINE_VMX GOTO parse_arguments
IF EXIST "%DOCKER_MACHINE_VMX%" GOTO parse_arguments

ECHO Correct environment variables to process
ECHO SET DOCKER_MACHINE_VMX=path/to/docker-machine.vmx
EXIT /B 1

:parse_arguments
SET "EXTRA_ARGS=%~2"
IF "%~1"=="start" GOTO process_arguments
IF "%~1"=="stop" GOTO start_process
IF "%~1"=="reset" GOTO start_process
IF "%~1"=="suspend" GOTO start_process

ECHO Usage: %~n0 [start^|stop^|reset^|suspend]
EXIT /B 1

:process_arguments
IF "%EXTRA_ARGS%"=="" SET EXTRA_ARGS=nogui

:start_process
SET APP_PATH=
FOR /F "skip=2 tokens=2*" %%H IN (
    'REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\vmplayer.exe" /ve'
) DO SET "APP_PATH=%%~dpI"

"%APP_PATH%vmrun.exe" %1 "%DOCKER_MACHINE_VMX%" %EXTRA_ARGS%
