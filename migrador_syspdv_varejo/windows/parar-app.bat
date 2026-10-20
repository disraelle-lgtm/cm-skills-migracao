@echo off
REM Para o servidor do migrador (porta 8020)
cd /d "%~dp0.."
taskkill /FI "WINDOWTITLE eq Servidor do Migrador SysPDV*" /T /F >nul 2>&1
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /R /C:":8020 .*LISTENING"') do taskkill /PID %%p /T /F >nul 2>&1
echo Migrador parado.
timeout /t 3 >nul
