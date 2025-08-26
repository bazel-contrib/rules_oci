@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
for %%a in (%BAZEL_SH%) do set "bash_bin_dir=%%~dpa"
set PATH=%bash_bin_dir%;%PATH%
set "parent_dir=%~dp0"
set "parent_dir=!parent_dir:\=/!"
set args=%*
rem Escape \ and * in args before passing it with double quote
if defined args (
  set args=!args:\=\\\\!
  set args=!args:"=\"!
)
%BAZEL_SH% -c "%parent_dir%descriptor.sh !args!"
