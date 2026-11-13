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
        # 1) tenta com a lista de pacotes que a maquina ja tem (sem apt-get update)
        if ! $SUDO apt-get install -y "${faltando[@]}"; then
            # 2) atualiza a lista. Um repositorio DE OUTRO PROGRAMA com problema (ex.: chave do MySQL
            #    vencida, "EXPKEYSIG") faz o apt-get update terminar com erro: isso NAO impede instalar
            #    os pacotes do migrador, que vem do repositorio oficial do Ubuntu - so avisa e segue.
            echo ">> Atualizando a lista de pacotes (apt-get update)..."
            if ! $SUDO apt-get update -qq; then
                echo
                echo "AVISO: o 'apt-get update' terminou com erro por causa de algum repositorio desta maquina"
                echo "       (veja as linhas 'E:' acima - ex.: repo.mysql.com com a chave vencida)."
                echo "       Isso e de outro programa, nao do migrador. Seguindo com a instalacao..."
                echo
            fi
            # 3) tenta de novo; se ainda faltar, explica o que fazer
            if ! $SUDO apt-get install -y "${faltando[@]}"; then
                echo
                echo "ERRO: nao consegui instalar: ${faltando[*]}"
                echo "Corrija o repositorio com problema mostrado acima e rode este instalador de novo."
                echo "Ex.: repositorio do MySQL com chave vencida - desative-o temporariamente:"
                echo "     sudo mv /etc/apt/sources.list.d/mysql.list /etc/apt/sources.list.d/mysql.list.desativado"
                echo "     (depois de instalar, volte o nome do arquivo e atualize a chave do MySQL)"
                exit 1
            fi
        fi
    else
        echo "Instale manualmente: ${faltando[*]}"; exit 1
    fi
fi

# ---- Driver ODBC do SQL Server (origem SQL Server e Validacao de Integridade do SQL Server)
# O SQL Server instalado e o SERVIDOR; o migrador conversa com ele pelo DRIVER ODBC (msodbcsql18), que e
# outro pacote. Sem ele so o SQL Server fica indisponivel: por isso, se falhar, so avisa e segue.
if command -v apt-get >/dev/null && ! (command -v odbcinst >/dev/null && odbcinst -q -d 2>/dev/null | grep -qi "SQL Server"); then
    echo ">> Instalando o driver ODBC do SQL Server (msodbcsql18) - usado so com SQL Server"
    id_so=$(. /etc/os-release 2>/dev/null; echo "${ID:-}")
    versao_so=$(. /etc/os-release 2>/dev/null; echo "${VERSION_ID:-}")
    if ! apt-cache policy msodbcsql18 2>/dev/null | grep -q "Candidate: [0-9]"; then
        # repositorio da Microsoft ainda nao configurado (quem instalou o SQL Server por ele ja tem)
        if [ "$id_so" = "ubuntu" ] && command -v curl >/dev/null \
           && curl -fsSL -o /tmp/packages-microsoft-prod.deb "https://packages.microsoft.com/config/ubuntu/$versao_so/packages-microsoft-prod.deb"; then
            $SUDO dpkg -i /tmp/packages-microsoft-prod.deb || true
            rm -f /tmp/packages-microsoft-prod.deb
            $SUDO apt-get update -qq || echo "AVISO: o 'apt-get update' deu erro em algum repositorio desta maquina (seguindo)."
        fi
    fi
    if $SUDO env ACCEPT_EULA=Y apt-get install -y msodbcsql18; then
        echo ">> Driver ODBC do SQL Server instalado."
    else
        echo
        echo "AVISO: nao consegui instalar o driver ODBC do SQL Server (msodbcsql18)."
        echo "       So faz falta para usar SQL Server (origem ou Validacao de Integridade). Passo a passo:"
        echo "       linux/LEIA-ME.md, secao 'Origem SQL Server'."
        echo
    fi
fi

echo ">> Criando ambiente virtual .venv"
python3 -m venv .venv
.venv/bin/python -m pip install --upgrade pip -q
.venv/bin/python -m pip install -r requirements.txt -q
chmod +x linux/*.sh 2>/dev/null || true

echo
echo "Pronto! Para abrir: bash linux/iniciar-app.sh  (abre http://127.0.0.1:8020)"

