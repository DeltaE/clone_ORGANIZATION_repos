@echo off
REM Simple script to clone all repositories from a GitHub organization (Windows)
REM Usage: clone_org_repos.bat [organization_name]

SETLOCAL ENABLEDELAYEDEXPANSION

REM Load config.env if exists
IF EXIST config.env (
    FOR /F "usebackq tokens=*" %%A IN (config.env) DO (
        SET "line=%%A"
        FOR /F "tokens=1,2 delims==" %%B IN ("!line!") DO (
            IF "%%B"=="ORG_NAME" SET ORG_NAME=%%C
            IF "%%B"=="API_URL" SET API_URL=%%C
            IF "%%B"=="GITHUB_TOKEN" SET GITHUB_TOKEN=%%C
        )
    )
) ELSE (
    SET API_URL=https://api.github.com/orgs
    SET ORG_NAME=DeltaE
)

REM Allow override from command line argument
IF NOT "%1"=="" SET ORG_NAME=%1

REM Create timestamped master folder
FOR /F %%I IN ('powershell -Command "Get-Date -Format yyyyMMdd_HHmmss"') DO SET TIMESTAMP=%%I
SET MASTER_FOLDER=%ORG_NAME%_%TIMESTAMP%

ECHO Creating master folder: %MASTER_FOLDER%
mkdir %MASTER_FOLDER%

REM Get repositories using curl and jq (jq required for Windows)
ECHO Fetching repositories for %ORG_NAME%...
SET PAGE=1
SET REPOS=
:fetch_loop
SET URL=%API_URL%/%ORG_NAME%/repos?page=%PAGE%&per_page=100
IF DEFINED GITHUB_TOKEN (
    SET HEADER=-H "Authorization: token %GITHUB_TOKEN%"
) ELSE (
    SET HEADER=
)
FOR /F "delims=" %%R IN ('curl -s %HEADER% "%URL%" ^| jq -r ".[].clone_url"') DO (
    IF "%%R"=="" GOTO end_fetch
    SET REPOS=!REPOS! %%R
)
SET /A PAGE+=1
GOTO fetch_loop
:end_fetch

REM Clone repositories
SET COUNT=0
FOR %%R IN (%REPOS%) DO (
    SET /A COUNT+=1
    SET REPO_NAME=%%~nR
    ECHO [!COUNT!] Cloning !REPO_NAME!...
    git clone %%R %MASTER_FOLDER%\!REPO_NAME!
)

ECHO All repositories cloned in: %CD%\%MASTER_FOLDER%
ENDLOCAL
