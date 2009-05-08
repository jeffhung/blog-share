@ECHO OFF
REM --------------------------------------------------------------------------
REM vc-build.bat - Batch script to ease building VC projects in console mode.
REM Copyright (c) 2008-2009, Jeff Hung
REM All rights reserved.
REM
REM Redistribution and use in source and binary forms, with or without
REM modification, are permitted provided that the following conditions
REM are met:
REM 
REM  - Redistributions of source code must retain the above copyright
REM    notice, this list of conditions and the following disclaimer.
REM  - Redistributions in binary form must reproduce the above copyright
REM    notice, this list of conditions and the following disclaimer in the
REM    documentation and/or other materials provided with the distribution.
REM  - Neither the name of the copyright holders nor the names of its
REM    contributors may be used to endorse or promote products derived
REM    from this software without specific prior written permission.
REM
REM THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
REM ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
REM LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
REM FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT
REM OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
REM SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
REM LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
REM DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
REM THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
REM (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
REM OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
REM --------------------------------------------------------------------------

IF "%1"==""       GOTO :USAGE
IF "%1"=="/?"     GOTO :USAGE
IF "%1"=="/h"     GOTO :USAGE
IF "%1"=="/help"  GOTO :USAGE
IF "%1"=="-h"     GOTO :USAGE
IF "%1"=="--help" GOTO :USAGE

SET VC_VERSION=%1
SET SOLUTION=%2
SET PROJECT=%3
SET CONFIGURATION=%4
SET ACTION=%5

IF "%VC_VERSION%"==""    CALL :MISSING_PARAM vc
IF "%SOLUTION%"==""      CALL :MISSING_PARAM solution
IF "%PROJECT%"==""       CALL :MISSING_PARAM project
IF "%CONFIGURATION%"=="" CALL :MISSING_PARAM configuration
IF "%ACTION%"==""        SET ACTION=BUILD

IF /I "%VC_VERSION%"=="vc6" CALL :SETUP_ENV_VC6
IF /I "%VC_VERSION%"=="vc8" CALL :SETUP_ENV_VC8
IF /I "%VC_VERSION%"=="vc9" CALL :SETUP_ENV_VC9

IF /I "%ACTION%"=="BUILD"   GOTO :SETUP_ACTION_BUILD
IF /I "%ACTION%"=="CLEAN"   GOTO :SETUP_ACTION_CLEAN
IF /I "%ACTION%"=="REBUILD" GOTO :SETUP_ACTION_REBUILD

ECHO {vc-build} -------------------------------------------------------------------
ECHO {vc-build}      vc version : %VC_VERSION%
ECHO {vc-build}        solution : %SOLUTION%
ECHO {vc-build}         project : %PROJECT%
ECHO {vc-build}   configuration : %CONFIGURATION%
ECHO {vc-build}          action : %ACTION%
ECHO {vc-build} -------------------------------------------------------------------
ECHO {vc-build} Loading VC environment variables
CALL "%VCVARS_PATH%"
ECHO {vc-build} Building project
%BUILD_CMD%
GOTO :EOF

:SETUP_ENV_VC6
SET MSVC_DIR=%ProgramFiles%\Microsoft Visual Studio
SET DEVENV_PATH=%MSVC_DIR%\Common\MSDev98\Bin\MSDEV.COM
SET VCVARS_PATH=%MSVC_DIR%\VC98\Bin\VCVARS32.BAT
IF /I "%ACTION%"=="BUILD"   SET ACTION=
IF /I "%ACTION%"=="CLEAN"   SET ACTION=/CLEAN
IF /I "%ACTION%"=="REBUILD" SET ACTION=/REBUILD
SET BUILD_CMD="%DEVENV_PATH%" "%SOLUTION%" /MAKE "%PROJECT% - Win32 %CONFIGURATION%" %ACTION%
GOTO :EOF

:SETUP_ENV_VC8
SET MSVC_DIR=%ProgramFiles%\Microsoft Visual Studio 8
SET DEVENV_PATH=%MSVC_DIR%\Common7\IDE\DevEnv.com
SET VCVARS_PATH=%MSVC_DIR%\VC\bin\vcvarS32.BAT
IF /I "%ACTION%"=="BUILD"   SET ACTION=/Build
IF /I "%ACTION%"=="CLEAN"   SET ACTION=/Clean
IF /I "%ACTION%"=="REBUILD" SET ACTION=/Rebuild
SET BUILD_CMD="%DEVENV_PATH%" "%SOLUTION%" /Project "%PROJECT%" /ProjectConfig "%CONFIGURATION%" %ACTION%
GOTO :EOF

:SETUP_ENV_VC9
SET MSVC_DIR=%ProgramFiles%\Microsoft Visual Studio 9.0
SET DEVENV_PATH=%MSVC_DIR%\Common7\IDE\DevEnv.com
SET VCVARS_PATH=%MSVC_DIR%\VC\bin\vcvarS32.BAT
IF /I "%ACTION%"=="BUILD"   SET ACTION=/Build
IF /I "%ACTION%"=="CLEAN"   SET ACTION=/Clean
IF /I "%ACTION%"=="REBUILD" SET ACTION=/Rebuild
SET BUILD_CMD="%DEVENV_PATH%" "%SOLUTION%" /Project "%PROJECT%" /ProjectConfig "%CONFIGURATION%" %ACTION%
GOTO :EOF

:MISSING_PARAM
ECHO Missing [%1]
GOTO :EOF

:USAGE
ECHO ------------------------------------------------------------------------------
ECHO Usage: %0 [vc] [solution] [project] [configuration]
ECHO Usage: %0 [vc] [solution] [project] [configuration] [action]
ECHO ------------------------------------------------------------------------------
ECHO             [vc] could be vc6, vc8, or vc9.
ECHO       [solution] is the .dsw or .sln file.
ECHO        [project] is the project to build.
ECHO  [configuration] could be Debug or Release, normally.
ECHO         [action] could be BUILD, REBUILD, or CLEAN (case insentively).
GOTO :EOF

