"""Pedidos de aprovação humana para ações que GRAVAM (migração, simulação, ajuste de códigos).

Fluxo:  pendente -> aprovada -> executando -> usada
        pendente -> recusada | expirada        aprovada -> expirada | invalidada

O servidor MCP só CRIA pedidos (solicitar_*) e os CONSOME uma vez (executar_pedido_aprovado).
Quem muda "pendente" para "aprovada" é o script aprovar_migracao.py, rodado pelo usuário num
terminal interativo. Nenhuma ferramenta MCP aprova pedidos.

Cada pedido guarda os parâmetros exatos e um hash deles: se algo mudar entre a aprovação e a
execução (parâmetros, itens, conteúdo dos SQLs), o pedido é recusado.
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import secrets
import time
from datetime import datetime
from pathlib import Path

PASTA = Path(os.environ.get("MCP_APROVACOES") or Path(__file__).resolve().parent / "aprovacoes")
_RE_ID = re.compile(r"^[0-9A-F]{6}$")

PENDENTE, APROVADA, EXECUTANDO, USADA = "pendente", "aprovada", "executando", "usada"
RECUSADA, EXPIRADA, INVALIDADA, INDETERMINADA = "recusada", "expirada", "invalidada", "indeterminada"


class ErroAprovacao(Exception):
    """Mensagem pensada para ser lida pelo Claude e pelo usuário."""


def agora() -> float:
    return time.time()


def iso(ts: float | None) -> str | None:
    return None if ts is None else datetime.fromtimestamp(ts).isoformat(timespec="seconds")


def hash_parametros(parametros: dict) -> str:
    bruto = json.dumps(parametros, sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    return hashlib.sha256(bruto.encode("utf-8")).hexdigest()


def _caminho(pedido_id: str) -> Path:
    pid = (pedido_id or "").strip().upper()
    if not _RE_ID.match(pid):
        raise ErroAprovacao("Código de pedido inválido (esperado 6 caracteres, ex.: A3F09C).")
    return PASTA / f"{pid}.json"


def _gravar(p: dict) -> None:
    PASTA.mkdir(parents=True, exist_ok=True)
    destino = _caminho(p["id"])
    tmp = destino.with_suffix(".tmp")
    tmp.write_text(json.dumps(p, ensure_ascii=False, indent=2), encoding="utf-8")
    os.replace(tmp, destino)


def carregar(pedido_id: str) -> dict:
    caminho = _caminho(pedido_id)
    if not caminho.exists():
        raise ErroAprovacao(f"Pedido {pedido_id.upper()} não existe.")
    p = json.loads(caminho.read_text(encoding="utf-8"))
    if p["estado"] in (PENDENTE, APROVADA) and agora() > p["expira_em"]:
        p["estado"] = EXPIRADA
        _gravar(p)
    return p


def criar(tipo: str, parametros: dict, resumo: dict, validade_minutos: int) -> dict:
    PASTA.mkdir(parents=True, exist_ok=True)
    while True:
        pid = secrets.token_hex(3).upper()
        if not _caminho(pid).exists():
            break
    criado = agora()
    p = {
        "id": pid,
        "tipo": tipo,                       # migracao | ajuste_codigos
        "estado": PENDENTE,
        "criado_em": criado,
        "expira_em": criado + validade_minutos * 60,
        "parametros": parametros,
        "hash": hash_parametros(parametros),
        "resumo": resumo,                   # o que o usuário vê ao aprovar (sem senhas)
        "aprovador": None,
        "aprovada_em": None,
        "resultado": None,
        "motivo": None,
    }
    _gravar(p)
    return p


def listar(estados: tuple[str, ...] | None = None) -> list[dict]:
    if not PASTA.exists():
        return []
    itens = []
    for arq in sorted(PASTA.glob("*.json")):
        try:
            p = carregar(arq.stem)
        except (ErroAprovacao, json.JSONDecodeError, KeyError):
            continue
        if estados is None or p["estado"] in estados:
            itens.append(p)
    return sorted(itens, key=lambda p: p["criado_em"])


# ------------------------------------------------------------ decisão humana
def aprovar(pedido_id: str, aprovador: str) -> dict:
    p = carregar(pedido_id)
    if p["estado"] != PENDENTE:
        raise ErroAprovacao(f"O pedido {p['id']} está '{p['estado']}', não pode ser aprovado.")
    if hash_parametros(p["parametros"]) != p["hash"]:
        p["estado"], p["motivo"] = INVALIDADA, "Parâmetros alterados depois do pedido."
        _gravar(p)
        raise ErroAprovacao("Os parâmetros do pedido foram alterados depois de criado. Peça um novo pedido.")
    p.update(estado=APROVADA, aprovador=aprovador, aprovada_em=agora())
    _gravar(p)
    return p


def recusar(pedido_id: str, quem: str) -> dict:
    p = carregar(pedido_id)
    if p["estado"] not in (PENDENTE, APROVADA):
        raise ErroAprovacao(f"O pedido {p['id']} está '{p['estado']}', não pode ser recusado.")
    p.update(estado=RECUSADA, aprovador=quem, motivo="Recusado pelo usuário.")
    _gravar(p)
    return p


# ------------------------------------------------------------------ execução
def reservar_execucao(pedido_id: str) -> dict:
    """Passa 'aprovada' para 'executando' uma única vez. Qualquer outra situação é recusada."""
    caminho = _caminho(pedido_id)
    trava = caminho.with_suffix(".lock")
    PASTA.mkdir(parents=True, exist_ok=True)
    try:
        fd = os.open(trava, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    except FileExistsError:
        raise ErroAprovacao("Este pedido já está sendo executado.") from None
    try:
        p = carregar(pedido_id)
        mensagens = {
            PENDENTE: "O usuário ainda NÃO aprovou. Peça que ele rode aprovar.bat e digite a frase de confirmação.",
            EXECUTANDO: "Este pedido já está em execução.",
            USADA: "Este pedido já foi executado (cada aprovação vale uma única vez). Faça um novo pedido.",
            RECUSADA: "O usuário recusou este pedido.",
            EXPIRADA: "O pedido expirou. Faça um novo pedido e peça nova aprovação.",
            INVALIDADA: "O pedido foi invalidado" + (f": {p.get('motivo')}" if p.get("motivo") else "") + ". Faça um novo pedido.",
            INDETERMINADA: "A execução deste pedido ficou indeterminada; confira o migrador antes de qualquer nova ação.",
        }
        if p["estado"] != APROVADA:
            raise ErroAprovacao(mensagens.get(p["estado"], f"Pedido em estado '{p['estado']}'."))
        if hash_parametros(p["parametros"]) != p["hash"]:
            p["estado"], p["motivo"] = INVALIDADA, "Parâmetros alterados depois da aprovação."
            _gravar(p)
            raise ErroAprovacao("Os parâmetros foram alterados depois da aprovação. Faça um novo pedido.")
        p["estado"] = EXECUTANDO
        _gravar(p)
        return p
    finally:
        os.close(fd)
        try:
            os.remove(trava)
        except OSError:
            pass


def _mudar(pedido_id: str, estado: str, **campos) -> dict:
    p = carregar(pedido_id)
    p["estado"] = estado
    p.update(campos)
    _gravar(p)
    return p


def concluir(pedido_id: str, resultado: dict) -> dict:
    return _mudar(pedido_id, USADA, resultado=resultado)


def liberar(pedido_id: str) -> dict:
    """Só quando se TEM CERTEZA de que nada começou (ex.: o migrador estava fechado)."""
    return _mudar(pedido_id, APROVADA)


def invalidar(pedido_id: str, motivo: str) -> dict:
    return _mudar(pedido_id, INVALIDADA, motivo=motivo)


def marcar_indeterminada(pedido_id: str, motivo: str) -> dict:
    return _mudar(pedido_id, INDETERMINADA, motivo=motivo)
