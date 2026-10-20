"""Usado pelo instalar-windows.ps1: python -m app.verificar_fbclient
Imprime 'OK <caminho>' se achou um fbclient que carrega, ou 'ERRO <motivo>'."""
from app.firebird_conexao import localizar_fbclient, mensagem_amigavel

try:
    print("OK " + str(localizar_fbclient(None) or "(fbclient do sistema)"))
except Exception as erro:  # noqa: BLE001
    print("ERRO " + mensagem_amigavel(erro))
