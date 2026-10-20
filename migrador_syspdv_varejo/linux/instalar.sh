#!/usr/bin/env bash
# Instalacao no Linux (Ubuntu/Debian). Uso (na pasta do migrador): bash linux/instalar.sh
set -e
cd "$(dirname "$0")/.."   # raiz do migrador (este script fica em linux/)

command -v python3 >/dev/null || { echo "Python 3 nao encontrado: sudo apt install python3"; exit 1; }
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' \
    || { echo "Precisa de Python 3.10 ou superior."; exit 1; }

# Dependencias do sistema que o pip nao instala
faltando=()
python3 -c "import ensurepip" 2>/dev/null || faltando+=(python3-venv)
# client Firebird 3.0 do sistema: conecta em servidor 2.5 e nao precisa da libncurses5
# (o client 2.5 de /opt/firebird precisa, e o Ubuntu 24.04 nao tem mais)
if command -v dpkg >/dev/null; then
    dpkg -s libfbclient2 >/dev/null 2>&1 || faltando+=(libfbclient2)
fi
command -v curl >/dev/null || faltando+=(curl)   # usado pelo iniciar-app.sh
command -v dpkg >/dev/null && { dpkg -s unixodbc >/dev/null 2>&1 || faltando+=(unixodbc); }   # origem SQL Server (pyodbc)

if [ ${#faltando[@]} -gt 0 ]; then
    if command -v apt-get >/dev/null; then
        SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
        echo ">> Instalando pacotes do sistema: ${faltando[*]}"
        $SUDO apt-get update -qq
        $SUDO apt-get install -y "${faltando[@]}"
    else
        echo "Instale manualmente: ${faltando[*]}"; exit 1
    fi
fi

echo ">> Criando ambiente virtual .venv"
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip -q
.venv/bin/python -m pip install -r requirements.txt -q
chmod +x linux/*.sh 2>/dev/null || true

echo
echo "Pronto! Para abrir: bash linux/iniciar-app.sh  (abre http://127.0.0.1:8020)"

