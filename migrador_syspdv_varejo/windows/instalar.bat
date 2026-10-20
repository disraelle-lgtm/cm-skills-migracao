@echo off
REM ====================================================================
REM  Instalador do Migrador SysPDV -> VarejoFacil (Windows)
REM
REM  1. Instala, um por um, os programas que ainda NAO estiverem no
REM     computador (o que ja existe e ignorado), procurando os instaladores
REM     na pasta Downloads (baixados do Drive interno):
REM       Firebird 2.5  ->  PostgreSQL 15  ->  pgAdmin 4  ->  Python 3.12
REM  2. Copia o migrador para a pasta DESTINO, instala as dependencias,
REM     e cria o atalho "Migrador SysPDV" na Area de Trabalho.
REM
REM  Ajuste aqui se precisar:
REM ====================================================================
set "DESTINO=C:\migrador_syspdv_varejo"
set "SENHA_POSTGRES=postgres"

cd /d "%~dp0"

REM Firebird e PostgreSQL instalam servicos: precisa de administrador.
net session >nul 2>&1
if errorlevel 1 (
    echo Pedindo permissao de administrador...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar-windows.ps1" -Destino "%DESTINO%" -SenhaPostgres "%SENHA_POSTGRES%"
echo.
pause
