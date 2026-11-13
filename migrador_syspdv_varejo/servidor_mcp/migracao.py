"""Ponte entre o MCP e o próprio migrador (API HTTP local, porta 8020).

O MCP NÃO reimplementa a migração: ele chama a mesma API que a tela do migrador usa
(/modulos, /migrar, /status, /codigos/*). Assim as regras, a ordem das etapas e os itens
automáticos continuam sendo exatamente os do app.
"""
from __future__ import annotations

import hashlib
import json
import socket
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import conexoes

RAIZ_APP = Path(__file__).resolve().parent.parent
HOSTS_LOCAIS = {"127.0.0.1", "localhost", "::1"}
LIMITE_ARQUIVO_DEPARA = 10 * 1024 * 1024


class ErroMigrador(Exception):
    """`nao_iniciou=True` só quando há certeza de que a ação NÃO começou no migrador."""

    def __init__(self, mensagem: str, nao_iniciou: bool = False):
        super().__init__(mensagem)
        self.nao_iniciou = nao_iniciou


def validar_url(url: str) -> str:
    u = urllib.parse.urlparse(url)
    if u.scheme != "http" or (u.hostname or "") not in HOSTS_LOCAIS:
        raise ErroMigrador(
            "app_url deve apontar para o próprio computador (http://127.0.0.1:PORTA): "
            "as senhas das conexões seguem nessa chamada."
        )
    return url.rstrip("/")


class Api:
    def __init__(self, base: str, timeout: int = 30):
        self.base = validar_url(base)
        self.timeout = timeout

    def _req(self, metodo: str, caminho: str, corpo: dict | None = None):
        dados = None if corpo is None else json.dumps(corpo).encode("utf-8")
        req = urllib.request.Request(
            self.base + caminho, data=dados, method=metodo, headers={"Content-Type": "application/json"}
        )
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            try:
                detalhe = json.loads(e.read().decode("utf-8")).get("detail", "")
            except Exception:
                detalhe = ""
            raise ErroMigrador(f"O migrador recusou ({e.code}): {detalhe or e.reason}", nao_iniciou=True) from None
        except urllib.error.URLError as e:
            if isinstance(e.reason, ConnectionRefusedError):
                raise ErroMigrador(
                    f"O migrador não está aberto em {self.base}. Abra windows\\iniciar-app.bat e tente de novo.",
                    nao_iniciou=True,
                ) from None
            raise ErroMigrador(f"Sem resposta do migrador em {self.base}: {e.reason}") from None
        except (socket.timeout, TimeoutError):
            raise ErroMigrador(f"O migrador não respondeu em {self.timeout}s.") from None

    def saude(self) -> dict:
        return self._req("GET", "/saude")

    def modulos(self, conjunto: str) -> list[dict]:
        return self._req("GET", "/modulos?" + urllib.parse.urlencode({"conjunto": conjunto}))

    def migrar(self, payload: dict) -> dict:
        return self._req("POST", "/migrar", payload)

    def status(self, exec_id: str, desde: int = 0) -> dict:
        return self._req("GET", f"/status/{urllib.parse.quote(exec_id)}?desde={int(desde)}")

    def consultar_codigos(self, payload: dict) -> dict:
        return self._req("POST", "/codigos/consultar", payload)

    def ajustar_codigos(self, payload: dict) -> dict:
        return self._req("POST", "/codigos/ajustar", payload)

    def status_ajuste(self, ajuste_id: str, desde: int = 0) -> dict:
        return self._req("GET", f"/codigos/status/{urllib.parse.quote(ajuste_id)}?desde={int(desde)}")


# --------------------------------------------------------------- conexões -> payload
def conexao_firebird(nome: str, c: dict) -> dict:
    d = {
        "host": c.get("host", "localhost"),
        "porta": int(c.get("porta", 3050)),
        "caminho": c["banco"],
        "usuario": c.get("usuario", "SYSDBA"),
        "senha": conexoes.senha_de(nome, c),
        "charset": c.get("charset", "WIN1252"),
    }
    for k in ("fbclient", "modo", "pasta_host", "pasta_container"):
        if c.get(k):
            d[k] = c[k]
    return d


def conexao_sqlserver(nome: str, c: dict) -> dict:
    d = {
        "host": c.get("host", "localhost"),
        "porta": int(c.get("porta", 1433)),
        "banco": c["banco"],
        "usuario": c.get("usuario", "sa"),
        "senha": conexoes.senha_de(nome, c),
    }
    for k in ("instancia", "driver", "string_odbc"):
        if c.get(k):
            d[k] = c[k]
    return d


def conexao_postgres(nome: str, c: dict) -> dict:
    return {
        "host": c.get("host", "localhost"),
        "port": int(c.get("porta", 5432)),
        "dbname": c["banco"],
        "user": c.get("usuario", "postgres"),
        "password": conexoes.senha_de(nome, c),
    }


# ------------------------------------------------------------------------- plano
def montar_plano(todos: list[dict], escolhidos_ids: list[str]) -> dict:
    """Mesma regra do app (motor.com_automaticos): itens marcados + automáticos do grupo/sempre."""
    ids = list(dict.fromkeys(escolhidos_ids))
    if not ids:
        raise ErroMigrador("Nenhum item informado.")
    por_id = {m["id"]: m for m in todos}
    invalidos = [
        i for i in ids
        if i not in por_id or por_id[i]["automatico_com_grupo"] or por_id[i]["automatico_sempre"]
    ]
    if invalidos:
        raise ErroMigrador(
            f"Itens inexistentes ou automáticos (não podem ser escolhidos): {', '.join(invalidos)}. "
            "Use listar_itens_migracao para ver os ids."
        )
    escolhidos = [por_id[i] for i in ids]
    problemas = [f"{m['id']}: {p}" for m in escolhidos for p in m["problemas"]]
    if problemas:
        raise ErroMigrador("O migrador aponta problemas nos itens escolhidos: " + "; ".join(problemas))
    grupos = {m["grupo"] for m in escolhidos}
    escolhidos_set = set(ids)
    extras = [
        m for m in todos
        if (m["automatico_com_grupo"] in grupos or m["automatico_sempre"]) and m["id"] not in escolhidos_set
    ]
    finais = sorted(escolhidos + extras, key=lambda m: m["id"])
    return {
        "escolhidos": ids,
        "automaticos": [
            {"id": m["id"], "nome": m["nome"], "descricao": m["descricao"]} for m in finais if m["id"] not in escolhidos_set
        ],
        "ordem_final": [m["id"] for m in finais],
        "etapas": sum(len(m["etapas"]) for m in finais),
        "_itens_finais": finais,
    }


def hash_comandos(itens_finais: list[dict], raiz: Path | None = None) -> str:
    """Hash do CONTEÚDO dos arquivos (SQL/Python) dos itens que vão rodar.

    Se alguém editar um inserir.sql entre a aprovação e a execução, o hash muda e o pedido cai.
    """
    raiz = raiz or RAIZ_APP
    h = hashlib.sha256()
    for m in itens_finais:
        pasta = raiz / m["pasta"]
        h.update(m["id"].encode())
        if not pasta.is_dir():
            h.update(b"<pasta-ausente>")
            continue
        for arq in sorted(p for p in pasta.rglob("*") if p.is_file() and "__pycache__" not in p.parts):
            h.update(str(arq.relative_to(pasta)).replace("\\", "/").encode())
            h.update(arq.read_bytes())
    return h.hexdigest()


def ler_depara(caminho: str) -> tuple[str, str]:
    """Lê o arquivo de códigos da virada. Devolve (texto, sha256 do conteúdo)."""
    p = Path(caminho).expanduser()
    if not p.is_file():
        raise ErroMigrador(f"Arquivo de códigos não encontrado: {caminho}")
    if p.stat().st_size > LIMITE_ARQUIVO_DEPARA:
        raise ErroMigrador("Arquivo de códigos grande demais (máximo 10 MB).")
    bruto = p.read_bytes()
    for enc in ("utf-8-sig", "cp1252"):
        try:
            return bruto.decode(enc), hashlib.sha256(bruto).hexdigest()
        except UnicodeDecodeError:
            continue
    raise ErroMigrador("Não consegui ler o arquivo de códigos (codificação desconhecida).")


# ----------------------------------------------------------------- status enxuto
def resumir_status(s: dict, max_log: int = 60) -> dict:
    """Reduz a resposta de /status ao que importa (o log completo pode ser enorme)."""
    log = s.get("log", [])
    return {
        "id": s.get("id"),
        "status": s.get("status"),
        "simulacao": s.get("simulacao"),
        "erro": s.get("erro"),
        "banco": s.get("banco"),
        "tempo_total_s": s.get("tempo_total"),
        "itens": {
            k: {
                c: v.get(c)
                for c in ("nome", "status", "lidos", "inseridos", "atualizados", "sem_alteracao", "pulados", "erros", "duracao", "mensagem")
            }
            for k, v in s.get("modulos", {}).items()
        },
        "log": log[-max_log:],
        "log_cortado": len(log) > max_log,
        "total_log": s.get("total_log"),
    }
