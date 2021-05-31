@ECHO OFF
SetLocal

SET "EXTRA_ARGS=%2"
IF "%1"=="start" GOTO start_process
IF "%1"=="stop" GOTO process
IF "%1"=="reset" GOTO process
IF "%1"=="suspend" GOTO process

ECHO Usage: %~n0 [start^|stop^|reset^|suspend]
EXIT /B 1

:start_process
IF "%EXTRA_ARGS%"=="" SET EXTRA_ARGS=nogui

:process
vmrun %1 "%DOCKER_VMACHINE_FILE%" %EXTRA_ARGS%
