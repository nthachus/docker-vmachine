@ECHO OFF
SETLOCAL

IF EXIST "%DOCKER_MACHINE_VMX%" GOTO parse_arguments

ECHO Correct environment variables to process
ECHO SET DOCKER_MACHINE_VMX=path/to/docker-machine.vmx
EXIT /B 1

:parse_arguments
SET "_CMD=%~1"
SET "EXTRA_ARGS=%~2"
IF "%_CMD%"=="start" GOTO process_start_cmd
IF "%_CMD%"=="stop" GOTO start_process
IF "%_CMD%"=="reset" GOTO start_process
IF "%_CMD%"=="suspend" GOTO start_process
IF "%_CMD%"=="revert" GOTO process_revert_cmd

ECHO Usage: %~n0 [start^|stop^|reset^|suspend^|revert]
EXIT /B 1

:process_start_cmd
IF "%EXTRA_ARGS%"=="" SET EXTRA_ARGS=nogui
GOTO start_process

:process_revert_cmd
SET "_CMD=%_CMD%ToSnapshot"
IF "%EXTRA_ARGS%"=="" SET EXTRA_ARGS=Initialized

:start_process
SET _APP_PATH=
FOR /F "skip=2 tokens=2*" %%H IN (
    'REG QUERY "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\vmplayer.exe" /ve'
) DO SET "_APP_PATH=%%~dpI"

"%_APP_PATH%vmrun" %_CMD% "%DOCKER_MACHINE_VMX%" %EXTRA_ARGS%
