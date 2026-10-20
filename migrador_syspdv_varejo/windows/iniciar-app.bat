@echo off
REM Sobe o migrador e abre o navegador em http://127.0.0.1:8020
REM Sempre para um migrador antigo que esteja na porta e so abre o navegador
REM quando confirmar que quem responde e ESTA versao.
setlocal EnableDelayedExpansion
title Iniciando o Migrador SysPDV - VarejoFacil
REM este arquivo fica em windows\ : o migrador roda a partir da pasta de cima
cd /d "%~dp0.."

set "PORTA=8020"
set "URL=http://127.0.0.1:%PORTA%"
set "TITULO=Servidor do Migrador SysPDV"

if not exist ".venv\Scripts\python.exe" (
    echo.
    echo ERRO: nao encontrei .venv\Scripts\python.exe nesta pasta.
    echo Rode primeiro a instalacao: duplo clique em windows\instalar.bat
    echo.
    pause
    exit /b 1
)

REM versao desta pasta (linha VERSAO = "..." do app\main.py)
set "VERSAO="
for /f tokens^=2^ delims^=^" %%v in ('findstr /B /C:"VERSAO = " app\main.py') do set "VERSAO=%%v"

set "TEMCURL=1"
where curl >nul 2>nul || set "TEMCURL=0"

REM ---------------------------------------------- porta ocupada?
netstat -ano | findstr /R /C:":%PORTA% .*LISTENING" >nul
if !errorlevel!==0 (
    set "RESP="
    if "!TEMCURL!"=="1" for /f "delims=" %%r in ('curl -s --max-time 2 %URL%/saude 2^>nul') do set "RESP=%%r"
    echo !RESP! | findstr /C:"migrador_syspdv_varejo" >nul
    if errorlevel 1 if "!TEMCURL!"=="1" (
        echo.
        echo ERRO: a porta %PORTA% esta ocupada por outro programa ^(nao e o migrador^).
        echo Veja quem e com:  netstat -ano ^| findstr :%PORTA%
        echo.
        pause
        exit /b 1
    )
    echo Parando o migrador que ja estava rodando para carregar esta versao...
    taskkill /FI "WINDOWTITLE eq %TITULO%*" /T /F >nul 2>&1
    taskkill /FI "WINDOWTITLE eq Migrador SysPDV*" /T /F >nul 2>&1
    for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":%PORTA% .*LISTENING"') do taskkill /PID %%p /T /F >nul 2>&1
    timeout /t 2 /nobreak >nul
)

REM ---------------------------------------------- sobe o servidor
echo Iniciando o servidor na janela "%TITULO%" (nao feche essa janela enquanto usar)...
start "%TITULO%" ".venv\Scripts\python.exe" -m uvicorn app.main:app --reload --reload-dir app --host 127.0.0.1 --port %PORTA%

if "!TEMCURL!"=="0" (
    echo Aguardando o servidor subir...
    timeout /t 6 /nobreak >nul
    goto abrir
)

set /a ESPERA=0
:esperar
timeout /t 1 /nobreak >nul
set /a ESPERA+=1
curl -s --max-time 1 %URL%/saude 2>nul | findstr /C:"!VERSAO!" >nul
if !errorlevel!==0 goto abrir
if !ESPERA! lss 30 goto esperar
echo.
echo ERRO: o servidor nao respondeu na versao !VERSAO!.
echo Veja a mensagem de erro na janela "%TITULO%".
echo.
pause
exit /b 1

:abrir
echo Pronto: %URL%   (versao !VERSAO!)
echo Para parar: feche a janela "%TITULO%" ou rode parar-app.bat
start "" "%URL%"
exit /b 0
