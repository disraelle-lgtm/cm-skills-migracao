#!/usr/bin/env bash
# Sobe o migrador e abre o navegador em http://127.0.0.1:8020
# Sempre derruba um servidor antigo do migrador que esteja na porta (de qualquer pasta)
# e so diz "Pronto" quando confirmar que quem responde e ESTA pasta, NESTA versao.
set -uo pipefail
cd "$(dirname "$0")/.."   # raiz do migrador (este script fica em linux/)

PORTA=8020
URL="http://127.0.0.1:${PORTA}"
VENV_PY=".venv/bin/python"
PID_FILE=".migrador.pid"
LOG_FILE="migrador.log"
PASTA="$(pwd)"
VERSAO="$(grep -o 'VERSAO = "[^"]*"' app/main.py | cut -d'"' -f2)"

[ -x "${VENV_PY}" ] || { echo "ERRO: rode primeiro a instalação: bash linux/instalar.sh"; exit 1; }

porta_ocupada() {
    curl -s -o /dev/null --max-time 1 "${URL}/" && return 0
    command -v fuser >/dev/null && fuser "${PORTA}/tcp" >/dev/null 2>&1 && return 0
    return 1
}

parar_migrador_na_porta() {
    # 1) pelo pid salvo nesta pasta
    if [ -f "${PID_FILE}" ]; then kill "$(cat "${PID_FILE}")" 2>/dev/null; rm -f "${PID_FILE}"; fi
    # 2) qualquer uvicorn do migrador nesta porta (de qualquer pasta)
    for pid in $(pgrep -f "uvicorn app.main:app.*--port ${PORTA}" 2>/dev/null); do
        case "$(ps -o comm= -p "${pid}" 2>/dev/null)" in python*) kill "${pid}" 2>/dev/null ;; esac
    done
    # 3) ultimo recurso: quem estiver escutando na porta
    command -v fuser >/dev/null && fuser -k "${PORTA}/tcp" >/dev/null 2>&1
    for _ in $(seq 1 20); do porta_ocupada || return 0; sleep 0.5; done
    return 1
}

RESPOSTA="$(curl -s --max-time 2 "${URL}/saude" || true)"
if echo "${RESPOSTA}" | grep -q '"app":"migrador_syspdv_varejo"'; then
    echo "Parando o migrador que já estava rodando para carregar esta versão..."
    parar_migrador_na_porta || { echo "ERRO: não consegui liberar a porta ${PORTA}. Rode: fuser -k ${PORTA}/tcp"; exit 1; }
elif porta_ocupada; then
    echo "ERRO: a porta ${PORTA} está ocupada por outro programa (não é o migrador)."
    echo "Veja quem é com: fuser -v ${PORTA}/tcp   e pare com: fuser -k ${PORTA}/tcp"
    exit 1
fi

echo "Iniciando o servidor (log em ${LOG_FILE})..."
nohup "${VENV_PY}" -m uvicorn app.main:app --reload --reload-dir app --host 127.0.0.1 --port "${PORTA}" \
    > "${LOG_FILE}" 2>&1 &
echo $! > "${PID_FILE}"

for _ in $(seq 1 30); do
    curl -s -o /dev/null --max-time 1 "${URL}/saude" && break
    sleep 0.5
done
RESPOSTA="$(curl -s --max-time 2 "${URL}/saude" || true)"
if ! echo "${RESPOSTA}" | grep -q "\"pasta\":\"${PASTA}\""; then
    echo "ERRO: o servidor desta pasta não subiu. Últimas linhas do ${LOG_FILE}:"
    tail -20 "${LOG_FILE}"
    exit 1
fi
if ! echo "${RESPOSTA}" | grep -q "\"versao\":\"${VERSAO}\""; then
    echo "ERRO: respondeu outra versão (${RESPOSTA}). Rode de novo: bash linux/iniciar-app.sh"
    exit 1
fi

echo "Pronto: ${URL}   (pasta ${PASTA}, versão ${VERSAO})"
echo "Para parar: kill \$(cat ${PID_FILE})"
if command -v xdg-open >/dev/null 2>&1; then xdg-open "${URL}" >/dev/null 2>&1 &
elif command -v open >/dev/null 2>&1; then open "${URL}"
fi
