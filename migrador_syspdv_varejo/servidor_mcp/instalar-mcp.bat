@echo off
cd /d "%~dp0"
if not exist "..\.venv\Scripts\python.exe" (
  echo Nao encontrei ..\.venv. Instale o migrador primeiro ^(windows\instalar.bat^) e rode este arquivo de novo.
  pause & exit /b 1
)
"..\.venv\Scripts\python.exe" -m pip install -r ..\requirements.txt -r requirements.txt || (pause & exit /b 1)
if not exist conexoes.json copy conexoes.exemplo.json conexoes.json
echo.
echo Pronto. Proximos passos: edite conexoes.json, defina as senhas com setx e registre o MCP no Claude (veja LEIA-ME-MCP.md).
pause
