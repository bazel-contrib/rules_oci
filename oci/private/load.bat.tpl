@echo off
setlocal enabledelayedexpansion

set RUNFILES
set RUNFILES_MANIFEST_ONLY=1

{{BATCH_RLOCATION_FUNCTION}}

REM Equivalent of bash errexit - exit on any error
rem if not defined RUNFILES_DIR (
rem     echo Error: RUNFILES_DIR not set >&2
rem     exit /b 1
rem )

REM Set paths using runfiles resolution
call :rlocation "{{tar}}" TAR
call :rlocation "{{mtree_path}}" MTREE
call :rlocation "{{loader}}" LOADER

REM Check if loader exists, otherwise find container CLI
set "CONTAINER_CLI="
if exist "%LOADER_PATH%" (
    set "CONTAINER_CLI=%LOADER_PATH%"
    goto :container_cli_found
)

REM Check for docker
where docker >nul 2>&1
if !errorlevel! equ 0 (
    set "CONTAINER_CLI=docker"
    goto :container_cli_found
)

REM Check for podman
where podman >nul 2>&1
if !errorlevel! equ 0 (
    set "CONTAINER_CLI=podman"
    goto :container_cli_found
)

REM Check for nerdctl
where nerdctl >nul 2>&1
if !errorlevel! equ 0 (
    set "CONTAINER_CLI=nerdctl"
    goto :container_cli_found
)

REM No container CLI found
echo Neither docker or podman or nerdctl could be found. >&2
echo To use a different container runtime, pass an executable to the 'loader' attribute of oci_tarball. >&2
exit /b 1

:container_cli_found

REM Read mtree contents and process it
if not exist "%MTREE%" (
    echo Error: mtree file not found: %MTREE% >&2
    exit /b 1
)

REM Strip manifest root and image root from mtree to make it compatible with runfiles layout
call :rlocation "{{image_root}}" IMAGE_ROOT
call :rlocation "{{manifest_root}}" MANIFEST_ROOT

REM Process mtree file - remove image_root and manifest_root prefixes
set "TEMP_MTREE=%TEMP%\mtree_processed_%RANDOM%.txt"
powershell -Command "& {(Get-Content '%MTREE%') -replace [regex]::Escape('%IMAGE_ROOT%'), '' -replace [regex]::Escape('%MANIFEST_ROOT%'), '' | Out-File -Encoding ASCII '%TEMP_MTREE%'}"

REM Convert runfiles directory path for tar command
set "WORKSPACE_DIR=%RUNFILES_DIR%\{{workspace_name}}"

REM Execute container load command using named pipe simulation
REM Windows doesn't have process substitution, so we use a different approach
set BAZEL
pwd
echo %cd%

set "CURDIR=%cd%"
for /f "delims=" %%A in ("!CURDIR!") do (
    set "ROOTDIR=%%A"
    for /f "delims=" %%B in ("!ROOTDIR:_main\=|!") do (
        set "ROOTDIR=!ROOTDIR:~0,-%%B!"
    )
)
set "ROOTDIR=%ROOTDIR%_main"
echo %ROOTDIR%

echo "%TAR%" -v --cd "%WORKSPACE_DIR%" --create --no-xattr --no-mac-metadata @"%TEMP_MTREE%"  >&2
"%TAR%" -v --cd "%WORKSPACE_DIR%" --create --no-xattr --no-mac-metadata @"%TEMP_MTREE%" > temp.tar
"%CONTAINER_CLI%" load temp.tar

REM Clean up temporary file
rem if exist "%TEMP_MTREE%" del "%TEMP_MTREE%"

if !errorlevel! neq 0 (
    echo Error: Container load failed >&2
    exit /b 1
)
