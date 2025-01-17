@echo off
setlocal EnableDelayedExpansion

set "launcherVersion=1.0.1"
set "launcherName=%~nx0"

REM Check system requirements
if not "%PROCESSOR_ARCHITECTURE%"=="AMD64" (
    echo This program requires 64-bit Windows
    pause
    exit /b 1
)

REM Get current version from file
if exist "version" (
    set /p "localVersion="<"version"
) else (
    set "localVersion=0.0.0"
)

REM Get the latest release info
echo Checking for updates...
echo.
for /f "delims=" %%i in ('powershell -Command "$tag = (Invoke-RestMethod -Uri 'https://api.github.com/repos/ketei/tagit-v3/releases/latest').tag_name; $tag -replace 'v','';"') do set "launcherReleaseVersion=%%i"
call :getUpdateType "!launcherReleaseVersion!" "%launcherVersion%"
set "launcherUpdateType=!errorlevel!"

if !launcherUpdateType! neq 0 (
    set "launcherUpdateArg=--update-launcher=!launcherName!"
    echo Launcher will be updated from "!launcherVersion!" to "!launcherReleaseVersion!" on next run
    echo.
)

REM Check if updates are disabled
if "!localVersion!"=="x" (
    start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
    exit /b 0
)

for /f "delims=" %%i in ('powershell -Command "$tag = (Invoke-RestMethod -Uri 'https://api.github.com/repos/ketei/tagit-launcher/releases/latest').tag_name; $tag -replace 'v','';"') do set "releaseVersion=%%i"

REM Determine the type of update required
call :getUpdateType "!releaseVersion!" "!localVersion!"
set "updateType=!errorlevel!"

REM Launch if no update is required
if !updateType! equ 0 (
    start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
    exit /b 0
)

REM Skip prompt if this is the first launch
if "!localVersion!"=="0.0.0" (
    echo First time setup
    goto download
)

:prompt
echo New version available: !releaseVersion!
echo Current version: !localVersion!
echo Would you like to update?
echo.
echo "(Y) Update Now"
echo "(N) Launch Without Update"
echo "(I) Ignore This Version"
echo "(X) Never Update"
choice /c YNIX /n
if errorlevel 4 (
    echo x>version
    start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
    exit /b 0
) else if errorlevel 3 (
    echo !releaseVersion!>version
    start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
    exit /b 0
) else if errorlevel 2 (
    start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
    exit /b 0
) else if errorlevel 1 (
    goto download
) else goto prompt

:download
if !updateType! geq 2 (
    echo Full update required
    set "pattern=(windows.*x86_64)|(\.pck$)"
) else (
    echo Partial update required
    set "pattern=\.pck$"
)

REM Download the latest release files
powershell -Command "$ProgressPreference = 'SilentlyContinue'; $Error.Clear(); try { $release = Invoke-RestMethod 'https://api.github.com/repos/ketei/tagit-launcher/releases/latest'; foreach ($asset in $release.assets) { if ($asset.name -match '%pattern%') { Write-Host ('Downloading {0}' -f $asset.browser_download_url); Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $asset.name } } } catch { Write-Host $_.Exception.Message; exit 1 }"

if errorlevel 1 (
    pause
    exit /b 1
)

REM Install the update
if exist "tagit.windows.x86_64.exe" (
    if exist "tagit.exe" del /f "tagit.exe"
    ren "tagit.windows.x86_64.exe" "tagit.exe"
)
echo !releaseVersion!>version
start "" "tagit.exe" -- --no-update "!launcherUpdateArg!"
exit /b 0

:getUpdateType
setlocal EnableDelayedExpansion
for /f "tokens=1,2,3 delims=." %%a in ("%~1") do (
    set /a "major1=%%a"
    set /a "minor1=%%b"
    set /a "patch1=%%c"
)
for /f "tokens=1,2,3 delims=." %%a in ("%~2") do (
    set /a "major2=%%a"
    set /a "minor2=%%b"
    set /a "patch2=%%c"
)

if !major1! neq !major2! (
    if !major1! gtr !major2! (exit /b 3) else (exit /b 0)
)

if !minor1! neq !minor2! (
    if !minor1! gtr !minor2! (exit /b 2) else (exit /b 0)
)

if !patch1! neq !patch2! (
    if !patch1! gtr !patch2! (exit /b 1) else (exit /b 0)
)
