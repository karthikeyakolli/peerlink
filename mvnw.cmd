@REM ----------------------------------------------------------------------------
@REM PeerLink Official Maven Wrapper for Windows (CMD/Batch)
@REM Pinned Apache Maven 3.9.9 Wrapper
@REM ----------------------------------------------------------------------------
@echo off
setlocal

set "WRAPPER_DIR=%~dp0"
set "MVN_PROPS=%WRAPPER_DIR%.mvn\wrapper\maven-wrapper.properties"

if not exist "%MVN_PROPS%" (
    echo ERROR: Cannot find %MVN_PROPS%
    exit /b 1
)

for /f "tokens=1,2 delims==" %%a in ('type "%MVN_PROPS%" ^| findstr /r "^distributionUrl="') do (
    set "DIST_URL=%%b"
)

if "%DIST_URL%"=="" (
    set "DIST_URL=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/3.9.9/apache-maven-3.9.9-bin.zip"
)

set "MAVEN_CACHE=%USERPROFILE%\.m2\wrapper\dists\apache-maven-3.9.9-bin"
set "MAVEN_HOME=%MAVEN_CACHE%\apache-maven-3.9.9"

if exist "%MAVEN_HOME%\bin\mvn.cmd" goto run_mvn

echo [mvnw] Apache Maven 3.9.9 is not cached. Downloading from %DIST_URL%...
if not exist "%MAVEN_CACHE%" mkdir "%MAVEN_CACHE%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop';" ^
  "$zip = Join-Path '%MAVEN_CACHE%' 'apache-maven-3.9.9-bin.zip';" ^
  "Write-Host '[mvnw] Downloading Maven 3.9.9...';" ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
  "Invoke-WebRequest -Uri '%DIST_URL%' -OutFile $zip;" ^
  "Write-Host '[mvnw] Extracting Maven 3.9.9...';" ^
  "Expand-Archive -Path $zip -DestinationPath '%MAVEN_CACHE%' -Force;" ^
  "Remove-Item -Force $zip;"

if not exist "%MAVEN_HOME%\bin\mvn.cmd" (
    echo [mvnw] ERROR: Failed to install Apache Maven 3.9.9.
    exit /b 1
)

echo [mvnw] Apache Maven 3.9.9 installed successfully to %MAVEN_HOME%.

:run_mvn
"%MAVEN_HOME%\bin\mvn.cmd" %*
exit /b %ERRORLEVEL%
