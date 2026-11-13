"""Validação de SQL somente leitura.

Esta é a PRIMEIRA barreira. A barreira que realmente importa é o usuário do banco:
use sempre um usuário com permissão apenas de leitura (veja o README).
"""
from __future__ import annotations

import re

PALAVRAS_PROIBIDAS = (
    "INSERT", "UPDATE", "DELETE", "MERGE", "DROP", "ALTER", "CREATE", "TRUNCATE",
    "GRANT", "REVOKE", "DENY", "EXEC", "EXECUTE", "CALL", "BACKUP", "RESTORE",
    "SHUTDOWN", "KILL", "RECONFIGURE", "WAITFOR", "DBCC", "BULK", "INTO",
    "OPENROWSET", "OPENQUERY", "OPENDATASOURCE", "COMMIT", "ROLLBACK",
    "SAVEPOINT", "LOCK", "SET", "USE", "DECLARE",
)
PALAVRAS_POSTGRES = (
    "COPY", "DO", "VACUUM", "ANALYZE", "REINDEX", "REFRESH", "NOTIFY", "LISTEN", "UNLISTEN",
    "PREPARE", "CLUSTER", "COMMENT", "LOAD", "IMPORT",
)
_RE_POSTGRES = re.compile(r"\b(" + "|".join(PALAVRAS_POSTGRES) + r")\b", re.IGNORECASE)
_RE_PG_FUNCOES = re.compile(
    r"\b(NEXTVAL|SETVAL|PG_SLEEP\w*|PG_READ_\w+|PG_LS_DIR|PG_STAT_FILE|PG_TERMINATE_BACKEND|"
    r"PG_CANCEL_BACKEND|SET_CONFIG|LO_IMPORT|LO_EXPORT|LO_UNLINK|DBLINK\w*|PG_ADVISORY\w*)\b",
    re.IGNORECASE,
)
_RE_DOLAR = re.compile(r"\$[A-Za-z_]*\$")   # $$ ... $$ e $tag$ ... $tag$: esconderiam comandos do validador
_RE_PROIBIDAS = re.compile(r"\b(" + "|".join(PALAVRAS_PROIBIDAS) + r")\b", re.IGNORECASE)
_RE_PROCS_SISTEMA = re.compile(r"\b(?:xp|sp)_\w+", re.IGNORECASE)
_RE_NEXT_VALUE = re.compile(r"\bNEXT\s+VALUE\s+FOR\b", re.IGNORECASE)
_RE_GEN_ID = re.compile(r"\bGEN_ID\s*\(([^)]*)\)", re.IGNORECASE)
_RE_SET_GENERATOR = re.compile(r"\bSET\s+GENERATOR\b", re.IGNORECASE)
_RE_IDENTIFICADOR = re.compile(r"^[A-Za-z_][A-Za-z0-9_$]*(\.[A-Za-z_][A-Za-z0-9_$]*)?$")


class SqlNaoPermitido(ValueError):
    pass


def _neutralizar(sql: str) -> str:
    """Remove comentários e esvazia literais/identificadores entre aspas.

    Assim, palavras dentro de textos ('UPDATE') ou nomes entre aspas não geram falso
    positivo, e comentários não escondem comandos.
    """
    saida: list[str] = []
    i, n = 0, len(sql)
    while i < n:
        c = sql[i]
        if sql.startswith("--", i):
            j = sql.find("\n", i)
            i = n if j == -1 else j
            saida.append(" ")
        elif sql.startswith("/*", i):
            j = sql.find("*/", i + 2)
            if j == -1:
                raise SqlNaoPermitido("Comentário /* ... */ sem fechamento.")
            i = j + 2
            saida.append(" ")
        elif c in ("'", '"', "["):
            fecha = "]" if c == "[" else c
            j = i + 1
            while True:
                if j >= n:
                    raise SqlNaoPermitido("Texto ou identificador entre aspas sem fechamento.")
                if sql[j] == fecha:
                    if fecha != "]" and sql.startswith(fecha * 2, j):  # '' ou "" escapado
                        j += 2
                        continue
                    break
                j += 1
            saida.append(c + "x" + fecha)
            i = j + 1
        else:
            saida.append(c)
            i += 1
    return "".join(saida)


def validar_somente_leitura(sql: str, dialeto: str | None = None) -> str:
    """Devolve o SQL original (sem ';' final) ou levanta SqlNaoPermitido.

    `dialeto` ("firebird", "sqlserver", "postgres") acrescenta as regras próprias do banco.
    """
    if not sql or not sql.strip():
        raise SqlNaoPermitido("SQL vazio.")
    if dialeto == "postgres" and _RE_DOLAR.search(sql):
        raise SqlNaoPermitido("Texto entre $$ ou $tag$ não é aceito (pode esconder comandos).")
    limpo = _neutralizar(sql).strip()
    while limpo.endswith(";"):
        limpo = limpo[:-1].rstrip()
    if ";" in limpo:
        raise SqlNaoPermitido("Apenas um comando por vez (encontrei ';' no meio do SQL).")
    primeira = re.match(r"\(*\s*([A-Za-z]+)", limpo)
    if not primeira or primeira.group(1).upper() not in ("SELECT", "WITH"):
        raise SqlNaoPermitido("Só são aceitas consultas que comecem com SELECT ou WITH.")
    achou = _RE_PROIBIDAS.search(limpo)
    if achou:
        raise SqlNaoPermitido(f"Palavra não permitida em consulta somente leitura: {achou.group(1).upper()}.")
    if dialeto == "postgres":
        achou = _RE_POSTGRES.search(limpo)
        if achou:
            raise SqlNaoPermitido(f"Palavra não permitida em consulta somente leitura (PostgreSQL): {achou.group(1).upper()}.")
        if _RE_PG_FUNCOES.search(limpo):
            raise SqlNaoPermitido("Função do PostgreSQL com efeito colateral ou acesso a arquivos não é permitida.")
    if _RE_PROCS_SISTEMA.search(limpo):
        raise SqlNaoPermitido("Procedures de sistema (xp_*/sp_*) não são permitidas.")
    if _RE_NEXT_VALUE.search(limpo) or _RE_SET_GENERATOR.search(limpo):
        raise SqlNaoPermitido("Sequences/generators não podem ser avançados por aqui.")
    for g in _RE_GEN_ID.finditer(limpo):
        incremento = g.group(1).rsplit(",", 1)
        if len(incremento) != 2 or incremento[1].strip() != "0":
            raise SqlNaoPermitido("GEN_ID só é permitido com incremento 0 (leitura do valor atual).")
    # devolve o SQL ORIGINAL sem o ';' final (o texto limpo é só para validar)
    original = sql.strip()
    while original.endswith(";"):
        original = original[:-1].rstrip()
    return original


def validar_identificador(nome: str) -> str:
    """Valida nome de tabela/view (aceita esquema.tabela). Impede injeção por nome."""
    nome = (nome or "").strip()
    if not _RE_IDENTIFICADOR.match(nome):
        raise SqlNaoPermitido(
            "Nome de tabela inválido. Use apenas letras, números, _ e $ (ex.: PRODUTO ou dbo.Produto)."
        )
    return nome
