"""Servidor MCP do Migrador SysPDV -> VarejoFacil (Casa Magalhães).

LEITURA livre (Firebird, SQL Server e PostgreSQL, sempre somente leitura) e MIGRAÇÃO apenas com
aprovação humana a cada pedido (veja aprovacoes.py).

Transporte: stdio (o cliente MCP — Claude Desktop, Claude Code — inicia este processo).
IMPORTANTE: nada pode ser escrito em stdout além do protocolo MCP; logs vão para stderr.
"""
from __future__ import annotations

import contextlib
import datetime as dt
import decimal
import json
import re
import sys
from pathlib import Path

from mcp.types import ToolAnnotations

try:  # mcp >= 2
    from mcp.server.mcpserver import MCPServer as _Servidor
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp import FastMCP as _Servidor

try:  # mcp >= 2
    from mcp.server.mcpserver.exceptions import ToolError
except ImportError:  # mcp 1.x
    from mcp.server.fastmcp.exceptions import ToolError

import aprovacoes
import conexoes
import migracao
from seguranca import SqlNaoPermitido, validar_identificador, validar_somente_leitura

class ErroUsuario(ToolError, ValueError):
    """Erro cuja mensagem o Claude precisa ler (SQL recusado, tabela inexistente, falha de conexão...).

    No SDK 2.x só um ToolError explícito leva a mensagem ao cliente; as demais exceções viram
    "Error executing tool".
    """


AUDITORIA = Path(__file__).resolve().parent / "auditoria.log"
SO_LEITURA = ToolAnnotations(readOnlyHint=True, destructiveHint=False, idempotentHint=True, openWorldHint=False)
CRIA_PEDIDO = ToolAnnotations(readOnlyHint=False, destructiveHint=False, idempotentHint=False, openWorldHint=False)
EXECUTA = ToolAnnotations(readOnlyHint=False, destructiveHint=True, idempotentHint=False, openWorldHint=False)

mcp = _Servidor(
    "migrador-cm",
    instructions=(
        "LEITURA (livre): consulte Firebird, SQL Server e PostgreSQL somente para leitura. Fluxo: listar_conexoes -> "
        "listar_tabelas -> descrever_tabela -> amostra_tabela -> executar_consulta. Firebird: SELECT FIRST n / ROWS n, "
        "nomes em maiúsculas. SQL Server: SELECT TOP (n), esquema.tabela. PostgreSQL: LIMIT n, nomes em minúsculas.\n"
        "MIGRAÇÃO (só com aprovação humana a cada pedido): você NUNCA executa uma migração por conta própria. "
        "Passos: 1) listar_itens_migracao; 2) solicitar_execucao (cria um pedido PENDENTE e não executa nada); "
        "3) diga ao usuário o código do pedido e peça que ele rode aprovar.bat e digite a frase de confirmação; "
        "4) só depois que o usuário disser que aprovou, chame executar_pedido_aprovado; 5) acompanhe com status_execucao "
        "e confira o resultado com consultas de leitura. Peça UM item por pedido, na ordem das pastas, e pare no primeiro "
        "erro. Cada aprovação vale uma única execução. Você não consegue aprovar nem recusar pedidos."
    ),
)


# ------------------------------------------------------------------ utilitários
def _auditar(conexao: str, ferramenta: str, detalhe: str) -> None:
    try:
        linha = re.sub(r"\s+", " ", detalhe).strip()[:600]
        with AUDITORIA.open("a", encoding="utf-8") as f:
            f.write(f"{dt.datetime.now().isoformat(timespec='seconds')}\t{conexao}\t{ferramenta}\t{linha}\n")
    except OSError:
        pass


def _config() -> dict:
    try:
        return conexoes.carregar_config()
    except conexoes.ErroConfig as e:
        raise ErroUsuario(str(e)) from e


def _conexao(cfg: dict, nome: str) -> dict:
    c = cfg["conexoes"].get(nome)
    if c is None:
        raise ErroUsuario(f"Conexão '{nome}' não existe. Disponíveis: {', '.join(cfg['conexoes'])}.")
    return c


def _valor(v):
    if v is None or isinstance(v, (bool, int, float, str)):
        return v
    if isinstance(v, decimal.Decimal):
        return str(v)  # preserva a precisão
    if isinstance(v, (dt.datetime, dt.date, dt.time)):
        return v.isoformat()
    if isinstance(v, (bytes, bytearray, memoryview)):
        return f"<binário {len(v)} bytes>"
    if isinstance(v, (dict, list)):  # json/jsonb do PostgreSQL
        return json.dumps(v, ensure_ascii=False, default=str)
    return str(v)


def _rodar(cfg: dict, nome: str, sql: str, params: tuple = (), limite: int | None = None, teto: int | None = None) -> dict:
    """Executa uma consulta e devolve colunas/linhas já serializadas (sem commit, sempre rollback)."""
    c = _conexao(cfg, nome)
    if c.get("uso", "leitura") == "migracao":
        raise ErroUsuario(
            f"A conexão '{nome}' é de MIGRAÇÃO (usuário com permissão de escrita) e não é usada para consultas. "
            "Use uma conexão de leitura."
        )
    limite = cfg["limite_linhas_padrao"] if limite is None else int(limite)
    limite = max(1, min(limite, teto or cfg["limite_linhas_maximo"]))
    try:
        conn = conexoes.conectar(nome, c, int(cfg["timeout_segundos"]))
    except conexoes.ErroConfig as e:
        raise ErroUsuario(str(e)) from e
    except ImportError as e:
        raise ErroUsuario(f"Driver não instalado para '{c['tipo']}': {e}. Rode 'pip install -r requirements.txt'.") from e
    except Exception as e:  # erro de rede/credencial: mensagem do driver, sem senha
        raise ErroUsuario(f"Falha ao conectar em '{nome}': {e}") from e
    try:
        cur = conn.cursor()
        cur.execute(sql, params) if params else cur.execute(sql)
        if cur.description is None:
            raise ErroUsuario("A consulta não retornou colunas.")
        colunas = [str(d[0]).strip() for d in cur.description]
        brutas = cur.fetchmany(limite + 1)
    except ErroUsuario:
        raise
    except Exception as e:
        raise ErroUsuario(f"Erro ao executar a consulta: {e}") from e
    finally:
        try:
            conn.rollback()
        except Exception:
            pass
        try:
            conn.close()
        except Exception:
            pass
    mascarar = {m.upper() for m in cfg["mascarar_colunas"]}
    ocultas = [i for i, col in enumerate(colunas) if col.upper() in mascarar]
    linhas = []
    for r in brutas[:limite]:
        lin = [_valor(x) for x in r]
        for i in ocultas:
            lin[i] = "***"
        linhas.append(lin)
    return {
        "conexao": nome,
        "colunas": colunas,
        "linhas": linhas,
        "linhas_retornadas": len(linhas),
        "truncado": len(brutas) > limite,
        "limite": limite,
    }


def _dicts(resultado: dict) -> list[dict]:
    return [dict(zip(resultado["colunas"], lin)) for lin in resultado["linhas"]]


# ------------------------------------------------------------------ metadados
_FB_TABELAS = (
    "SELECT TRIM(r.RDB$RELATION_NAME) AS NOME, "
    "CASE WHEN r.RDB$VIEW_BLR IS NULL THEN 'TABELA' ELSE 'VIEW' END AS TIPO "
    "FROM RDB$RELATIONS r WHERE COALESCE(r.RDB$SYSTEM_FLAG, 0) = 0 ORDER BY 1"
)
_FB_COLUNAS = (
    "SELECT TRIM(rf.RDB$FIELD_NAME) AS COLUNA, TRIM(t.RDB$TYPE_NAME) AS TIPO, "
    "f.RDB$CHARACTER_LENGTH AS TAMANHO, f.RDB$FIELD_PRECISION AS PRECISAO, f.RDB$FIELD_SCALE AS ESCALA, "
    "f.RDB$FIELD_SUB_TYPE AS SUBTIPO, rf.RDB$NULL_FLAG AS NN_COLUNA, f.RDB$NULL_FLAG AS NN_DOMINIO "
    "FROM RDB$RELATION_FIELDS rf "
    "JOIN RDB$FIELDS f ON f.RDB$FIELD_NAME = rf.RDB$FIELD_SOURCE "
    "JOIN RDB$TYPES t ON t.RDB$FIELD_NAME = 'RDB$FIELD_TYPE' AND t.RDB$TYPE = f.RDB$FIELD_TYPE "
    "WHERE rf.RDB$RELATION_NAME = ? ORDER BY rf.RDB$FIELD_POSITION"
)
_FB_PK = (
    "SELECT TRIM(s.RDB$FIELD_NAME) AS COLUNA FROM RDB$RELATION_CONSTRAINTS rc "
    "JOIN RDB$INDEX_SEGMENTS s ON s.RDB$INDEX_NAME = rc.RDB$INDEX_NAME "
    "WHERE rc.RDB$RELATION_NAME = ? AND rc.RDB$CONSTRAINT_TYPE = 'PRIMARY KEY' ORDER BY s.RDB$FIELD_POSITION"
)
_MS_TABELAS = (
    "SELECT TABLE_SCHEMA + '.' + TABLE_NAME AS NOME, "
    "CASE TABLE_TYPE WHEN 'VIEW' THEN 'VIEW' ELSE 'TABELA' END AS TIPO "
    "FROM INFORMATION_SCHEMA.TABLES ORDER BY 1"
)
_MS_COLUNAS = (
    "SELECT COLUMN_NAME AS COLUNA, DATA_TYPE AS TIPO, CHARACTER_MAXIMUM_LENGTH AS TAMANHO, "
    "NUMERIC_PRECISION AS PRECISAO, NUMERIC_SCALE AS ESCALA, IS_NULLABLE AS NULAVEL "
    "FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION"
)
_MS_PK = (
    "SELECT k.COLUMN_NAME AS COLUNA FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc "
    "JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE k ON k.CONSTRAINT_NAME = tc.CONSTRAINT_NAME "
    "AND k.TABLE_SCHEMA = tc.TABLE_SCHEMA WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY' "
    "AND tc.TABLE_SCHEMA = ? AND tc.TABLE_NAME = ? ORDER BY k.ORDINAL_POSITION"
)


_PG_TABELAS = (
    "SELECT table_schema || '.' || table_name AS NOME, "
    "CASE table_type WHEN 'VIEW' THEN 'VIEW' ELSE 'TABELA' END AS TIPO "
    "FROM information_schema.tables WHERE table_schema NOT IN ('pg_catalog', 'information_schema') ORDER BY 1"
)
_PG_COLUNAS = (
    "SELECT column_name AS COLUNA, data_type AS TIPO, character_maximum_length AS TAMANHO, "
    "numeric_precision AS PRECISAO, numeric_scale AS ESCALA, is_nullable AS NULAVEL "
    "FROM information_schema.columns WHERE table_schema = %s AND table_name = %s ORDER BY ordinal_position"
)
_PG_PK = (
    "SELECT k.column_name AS COLUNA FROM information_schema.table_constraints tc "
    "JOIN information_schema.key_column_usage k ON k.constraint_name = tc.constraint_name "
    "AND k.table_schema = tc.table_schema WHERE tc.constraint_type = 'PRIMARY KEY' "
    "AND tc.table_schema = %s AND tc.table_name = %s ORDER BY k.ordinal_position"
)


def _tipo_firebird(c: dict) -> str:
    tipo = (c["TIPO"] or "").strip()
    escala = -(c["ESCALA"] or 0)
    if tipo in ("VARYING", "TEXT"):
        return f"{'VARCHAR' if tipo == 'VARYING' else 'CHAR'}({c['TAMANHO']})"
    if tipo in ("SHORT", "LONG", "INT64") and escala > 0:
        return f"NUMERIC({c['PRECISAO'] or 18},{escala})"
    if tipo == "BLOB":
        return "BLOB SUB_TYPE TEXT" if c["SUBTIPO"] == 1 else "BLOB"
    return {"SHORT": "SMALLINT", "LONG": "INTEGER", "INT64": "BIGINT", "DOUBLE": "DOUBLE PRECISION"}.get(tipo, tipo)


def _tipo_sqlserver(c: dict) -> str:
    tipo, tam = c["TIPO"], c["TAMANHO"]
    if tam is not None:
        return f"{tipo}({'max' if tam == -1 else tam})"
    if tipo in ("decimal", "numeric"):
        return f"{tipo}({c['PRECISAO']},{c['ESCALA']})"
    return tipo


def _separar(tabela: str, padrao: str = "dbo") -> tuple[str, str]:
    partes = tabela.split(".")
    return (partes[0], partes[1]) if len(partes) == 2 else (padrao, partes[0])


# ------------------------------------------------------------------ ferramentas
@mcp.tool(annotations=SO_LEITURA)
def listar_conexoes() -> list[dict]:
    """Lista as conexões (nome, tipo, uso, servidor, banco). `uso=leitura` serve para consultas; `uso=migracao` só para migrar. Não expõe senhas."""
    cfg = _config()
    return [
        {
            "nome": n, "tipo": c["tipo"], "uso": c.get("uso", "leitura"), "host": c.get("host", "localhost"),
            "banco": c["banco"], "descricao": c.get("descricao", ""),
        }
        for n, c in cfg["conexoes"].items()
    ]


@mcp.tool(annotations=SO_LEITURA)
def testar_conexao(conexao: str) -> dict:
    """Testa a conexão e devolve a versão do servidor."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    sql = {
        "firebird": "SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') AS VERSAO FROM RDB$DATABASE",
        "sqlserver": "SELECT @@VERSION AS VERSAO",
        "postgres": "SELECT version() AS VERSAO",
    }[c["tipo"]]
    _auditar(conexao, "testar_conexao", "")
    r = _rodar(cfg, conexao, sql, limite=1)
    return {"conexao": conexao, "tipo": c["tipo"], "ok": True, "versao": r["linhas"][0][0]}


@mcp.tool(annotations=SO_LEITURA)
def listar_tabelas(conexao: str, filtro: str = "") -> dict:
    """Lista tabelas e views do banco. `filtro` busca por parte do nome (sem diferenciar maiúsculas)."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    _auditar(conexao, "listar_tabelas", filtro)
    r = _rodar(cfg, conexao, {"firebird": _FB_TABELAS, "sqlserver": _MS_TABELAS, "postgres": _PG_TABELAS}[c["tipo"]], limite=20000, teto=20000)
    itens = _dicts(r)
    if filtro.strip():
        f = filtro.strip().upper()
        itens = [i for i in itens if f in i["NOME"].upper()]
    total = len(itens)
    itens = itens[:500]
    return {"conexao": conexao, "total": total, "mostrando": len(itens), "tabelas": itens}


@mcp.tool(annotations=SO_LEITURA)
def descrever_tabela(conexao: str, tabela: str) -> dict:
    """Mostra colunas (tipo, tamanho, se aceita nulo) e chave primária de uma tabela ou view."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    try:
        tabela = validar_identificador(tabela)
    except SqlNaoPermitido as e:
        raise ErroUsuario(str(e)) from e
    _auditar(conexao, "descrever_tabela", tabela)
    if c["tipo"] == "firebird":
        params = (tabela.upper(),)
        cols = _dicts(_rodar(cfg, conexao, _FB_COLUNAS, params, limite=cfg["limite_linhas_maximo"]))
        pk = [x["COLUNA"] for x in _dicts(_rodar(cfg, conexao, _FB_PK, params, limite=50))]
        saida = [
            {"coluna": x["COLUNA"], "tipo": _tipo_firebird(x), "obrigatorio": bool(x["NN_COLUNA"] or x["NN_DOMINIO"])}
            for x in cols
        ]
    else:
        postgres = c["tipo"] == "postgres"
        params = _separar(tabela.lower(), "public") if postgres else _separar(tabela)
        colunas_sql, pk_sql = (_PG_COLUNAS, _PG_PK) if postgres else (_MS_COLUNAS, _MS_PK)
        cols = _dicts(_rodar(cfg, conexao, colunas_sql, params, limite=cfg["limite_linhas_maximo"]))
        pk = [x["COLUNA"] for x in _dicts(_rodar(cfg, conexao, pk_sql, params, limite=50))]
        saida = [{"coluna": x["COLUNA"], "tipo": _tipo_sqlserver(x), "obrigatorio": x["NULAVEL"] == "NO"} for x in cols]
    if not saida:
        raise ErroUsuario(f"Tabela '{tabela}' não encontrada em '{conexao}'. Use listar_tabelas para conferir o nome.")
    return {"conexao": conexao, "tabela": tabela, "chave_primaria": pk, "colunas": saida}


@mcp.tool(annotations=SO_LEITURA)
def amostra_tabela(conexao: str, tabela: str, linhas: int = 10) -> dict:
    """Devolve as primeiras linhas de uma tabela (até 100) para conhecer os dados."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    try:
        tabela = validar_identificador(tabela)
    except SqlNaoPermitido as e:
        raise ErroUsuario(str(e)) from e
    n = max(1, min(int(linhas), 100))
    _auditar(conexao, "amostra_tabela", f"{tabela} ({n})")
    if c["tipo"] == "firebird":
        sql = f'SELECT FIRST {n} * FROM "{tabela.upper()}"'
    elif c["tipo"] == "postgres":
        esq, nome = _separar(tabela.lower(), "public")
        sql = f'SELECT * FROM "{esq}"."{nome}" LIMIT {n}'
    else:
        esq, nome = _separar(tabela)
        sql = f"SELECT TOP ({n}) * FROM [{esq}].[{nome}]"
    return _rodar(cfg, conexao, sql, limite=n)


@mcp.tool(annotations=SO_LEITURA)
def executar_consulta(conexao: str, sql: str, limite: int | None = None) -> dict:
    """Executa UMA consulta SELECT/WITH somente leitura (qualquer um dos 3 bancos). O resultado é cortado em `limite` linhas."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    try:
        sql_ok = validar_somente_leitura(sql, c["tipo"])
    except SqlNaoPermitido as e:
        _auditar(conexao, "BLOQUEADO", sql)
        raise ErroUsuario(f"SQL recusado: {e}") from e
    _auditar(conexao, "executar_consulta", sql_ok)
    return _rodar(cfg, conexao, sql_ok, limite=limite)


# ================================================================== MIGRAÇÃO
# Regra de ouro: nenhuma ferramenta daqui aprova pedidos. Quem aprova é o usuário, no terminal
# (aprovar_migracao.py). executar_pedido_aprovado só roda pedidos JÁ aprovados, uma única vez.

CONJUNTOS = ("inicial", "virada")


@contextlib.contextmanager
def _erros():
    try:
        yield
    except (migracao.ErroMigrador, aprovacoes.ErroAprovacao, conexoes.ErroConfig) as e:
        raise ErroUsuario(str(e)) from e


def _api(cfg: dict) -> "migracao.Api":
    return migracao.Api(cfg["app_url"])


def _origem(cfg: dict, nome: str) -> dict:
    c = _conexao(cfg, nome)
    if c["tipo"] not in ("firebird", "sqlserver"):
        raise ErroUsuario(f"A origem '{nome}' precisa ser Firebird ou SQL Server (é {c['tipo']}).")
    return c


def _destino(cfg: dict, nome: str) -> dict:
    c = _conexao(cfg, nome)
    if c["tipo"] != "postgres" or c.get("uso") != "migracao":
        raise ErroUsuario(
            f"O destino '{nome}' precisa ser uma conexão PostgreSQL com \"uso\": \"migracao\" no conexoes.json "
            "(usuário com permissão de escrita, separado das conexões de leitura)."
        )
    return c


def _servidor(c: dict) -> str:
    porta = c.get("porta") or {"firebird": 3050, "sqlserver": 1433, "postgres": 5432}[c["tipo"]]
    return f"{c.get('host', 'localhost')}:{porta}"


def _payload_migracao(cfg: dict, par: dict, depara: dict | None) -> dict:
    co, cd = _origem(cfg, par["origem"]), _destino(cfg, par["destino"])
    payload = {
        "origem_tipo": co["tipo"],
        "conjunto": par["conjunto"],
        "postgres": migracao.conexao_postgres(par["destino"], cd),
        "modulos": par["modulos"],
        "simular": par["simular"],
        "opcoes": par["opcoes"],
    }
    if co["tipo"] == "firebird":
        payload["firebird"] = migracao.conexao_firebird(par["origem"], co)
    else:
        payload["sqlserver"] = migracao.conexao_sqlserver(par["origem"], co)
    if depara:
        payload.update(depara)
    return payload


@mcp.tool(annotations=SO_LEITURA)
def status_migrador() -> dict:
    """Confere se o migrador (tela/API na porta 8020) está aberto e qual versão está rodando."""
    cfg = _config()
    try:
        s = _api(cfg).saude()
        return {"aberto": True, "url": cfg["app_url"], "versao": s.get("versao"), "pasta": s.get("pasta"), "sistema": s.get("sistema")}
    except migracao.ErroMigrador as e:
        return {"aberto": False, "url": cfg["app_url"], "detalhe": str(e)}


@mcp.tool(annotations=SO_LEITURA)
def listar_itens_migracao(conjunto: str = "inicial") -> list[dict]:
    """Lista os itens (etapas) do migrador. conjunto: 'inicial' (comandos/) ou 'virada' (comandos_virada/). Itens automáticos entram sozinhos."""
    if conjunto not in CONJUNTOS:
        raise ErroUsuario(f"conjunto deve ser um de {CONJUNTOS}.")
    cfg = _config()
    with _erros():
        itens = _api(cfg).modulos(conjunto)
    saida = []
    for m in itens:
        auto = "sempre (entra em toda migração)" if m["automatico_sempre"] else (
            f"com o grupo '{m['automatico_com_grupo']}'" if m["automatico_com_grupo"] else None)
        saida.append({
            "id": m["id"], "nome": m["nome"], "grupo": m["grupo"], "descricao": (m["descricao"] or "")[:300],
            "etapas": len(m["etapas"]), "automatico": auto, "opcoes": m["opcoes"], "problemas": m["problemas"],
        })
    return saida


@mcp.tool(annotations=SO_LEITURA)
def consultar_codigos(conexao: str, clientes: bool = False, produtos: bool = False) -> dict:
    """Prévia (nada é alterado): quantos clientes/produtos têm código >= 999999 no VarejoFacil (PostgreSQL)."""
    cfg = _config()
    c = _conexao(cfg, conexao)
    if c["tipo"] != "postgres":
        raise ErroUsuario("Use uma conexão PostgreSQL (VarejoFacil).")
    if not (clientes or produtos):
        raise ErroUsuario("Marque clientes e/ou produtos.")
    _auditar(conexao, "consultar_codigos", f"clientes={clientes} produtos={produtos}")
    with _erros():
        return _api(cfg).consultar_codigos(
            {"postgres": migracao.conexao_postgres(conexao, c), "clientes": clientes, "produtos": produtos})


@mcp.tool(annotations=CRIA_PEDIDO)
def solicitar_execucao(
    origem: str,
    destino: str,
    itens: list[str],
    conjunto: str = "inicial",
    simular: bool = True,
    opcoes: dict[str, bool] | None = None,
    depara_clientes_arquivo: str | None = None,
    depara_produtos_arquivo: str | None = None,
) -> dict:
    """Cria um PEDIDO de execução (nada é executado). Devolve o código do pedido para o usuário aprovar no terminal.

    origem: conexão Firebird/SQL Server. destino: conexão PostgreSQL com uso=migracao. itens: ids de listar_itens_migracao
    (normalmente UM por pedido). simular=True roda e desfaz no fim; simular=False GRAVA no destino.
    """
    cfg = _config()
    if conjunto not in CONJUNTOS:
        raise ErroUsuario(f"conjunto deve ser um de {CONJUNTOS}.")
    co, cd = _origem(cfg, origem), _destino(cfg, destino)
    opcoes = opcoes or {}
    if not all(isinstance(v, bool) for v in opcoes.values()):
        raise ErroUsuario("opcoes deve ter apenas valores verdadeiro/falso.")
    ids = list(dict.fromkeys(itens or []))
    if len(ids) > cfg["max_itens_por_aprovacao"]:
        raise ErroUsuario(
            f"Cada aprovação cobre no máximo {cfg['max_itens_por_aprovacao']} item(ns); você pediu {len(ids)}. "
            "Faça um pedido por etapa (ou aumente max_itens_por_aprovacao no conexoes.json)."
        )
    depara = {"clientes_arquivo": None, "clientes_sha": None, "produtos_arquivo": None, "produtos_sha": None}
    if (depara_clientes_arquivo or depara_produtos_arquivo) and conjunto != "virada":
        raise ErroUsuario("Arquivos de códigos só valem para o conjunto 'virada'.")
    with _erros():
        for chave, caminho in (("clientes", depara_clientes_arquivo), ("produtos", depara_produtos_arquivo)):
            if caminho:
                _, sha = migracao.ler_depara(caminho)
                depara[f"{chave}_arquivo"], depara[f"{chave}_sha"] = str(Path(caminho).expanduser().resolve()), sha
        todos = _api(cfg).modulos(conjunto)
        plano = migracao.montar_plano(todos, ids)
        hash_cmd = migracao.hash_comandos(plano["_itens_finais"])
    por_id = {m["id"]: m for m in todos}
    parametros = {
        "tipo": "migracao", "origem": origem, "destino": destino, "conjunto": conjunto, "modulos": plano["escolhidos"],
        "simular": bool(simular), "opcoes": opcoes, "ordem_final": plano["ordem_final"], "hash_comandos": hash_cmd,
        "depara": depara,
    }
    avisos = (
        ["SIMULAÇÃO: tudo é desfeito no final, MAS o finalizar.sql de cada etapa é confirmado e os contadores "
         "(sequences) do PostgreSQL não voltam atrás."]
        if simular else
        ["GRAVA no banco de destino. Cada etapa é confirmada (commit) ao terminar: o que já concluiu NÃO é desfeito "
         "automaticamente se uma etapa seguinte falhar."]
    )
    if plano["automaticos"]:
        avisos.append("Itens automáticos entram junto nesta execução (veja a lista).")
    resumo = {
        "titulo": ("SIMULAÇÃO" if simular else "MIGRAÇÃO REAL") + f" — conjunto {conjunto}",
        "real": not simular,
        "origem": {"nome": origem, "tipo": co["tipo"], "servidor": _servidor(co), "banco": co["banco"]},
        "destino": {"nome": destino, "servidor": _servidor(cd), "banco": cd["banco"], "usuario": cd.get("usuario", "postgres")},
        "itens_escolhidos": [{"id": i, "nome": por_id[i]["nome"], "descricao": (por_id[i]["descricao"] or "")[:400]} for i in plano["escolhidos"]],
        "itens_automaticos": plano["automaticos"],
        "etapas_total": plano["etapas"],
        "opcoes": opcoes,
        "arquivos_de_codigos": {k: v for k, v in depara.items() if k.endswith("_arquivo") and v},
        "avisos": avisos,
        "frase_confirmacao": cd["banco"] if not simular else "SIMULAR",
    }
    with _erros():
        pedido = aprovacoes.criar("migracao", parametros, resumo, cfg["aprovacao_validade_minutos"])
    _auditar(destino, "solicitar_execucao", f"{pedido['id']} {conjunto} {ids} simular={simular}")
    return _resposta_pedido(pedido, resumo)


@mcp.tool(annotations=CRIA_PEDIDO)
def solicitar_ajuste_codigos(destino: str, clientes: bool = False, produtos: bool = False) -> dict:
    """Cria um PEDIDO para ajustar códigos >= 999999 de clientes/produtos no VarejoFacil (ALTERA o banco). Nada é executado."""
    cfg = _config()
    cd = _destino(cfg, destino)
    if not (clientes or produtos):
        raise ErroUsuario("Marque clientes e/ou produtos.")
    with _erros():
        previa = _api(cfg).consultar_codigos(
            {"postgres": migracao.conexao_postgres(destino, cd), "clientes": clientes, "produtos": produtos})
    parametros = {"tipo": "ajuste_codigos", "destino": destino, "clientes": clientes, "produtos": produtos}
    resumo = {
        "titulo": "AJUSTE DE CÓDIGOS (grava no banco)",
        "real": True,
        "destino": {"nome": destino, "servidor": _servidor(cd), "banco": cd["banco"], "usuario": cd.get("usuario", "postgres")},
        "itens_escolhidos": [{"id": q, "nome": q.capitalize(), "descricao": "Códigos >= 999999 recebem um código livre."}
                             for q, marcado in (("clientes", clientes), ("produtos", produtos)) if marcado],
        "itens_automaticos": [], "etapas_total": int(clientes) + int(produtos), "opcoes": {},
        "previa": previa,
        "avisos": ["Altera códigos no banco de destino, numa transação única (se falhar, nada é gravado). "
                   "Gera planilhas em reports\\codigos."],
        "frase_confirmacao": cd["banco"],
    }
    with _erros():
        pedido = aprovacoes.criar("ajuste_codigos", parametros, resumo, cfg["aprovacao_validade_minutos"])
    _auditar(destino, "solicitar_ajuste_codigos", f"{pedido['id']} clientes={clientes} produtos={produtos}")
    return _resposta_pedido(pedido, resumo)


def _resposta_pedido(pedido: dict, resumo: dict) -> dict:
    return {
        "pedido_id": pedido["id"],
        "estado": pedido["estado"],
        "expira_em": aprovacoes.iso(pedido["expira_em"]),
        "resumo": {k: resumo[k] for k in ("titulo", "origem", "destino", "itens_escolhidos", "itens_automaticos",
                                          "etapas_total", "avisos") if k in resumo},
        "frase_de_confirmacao": resumo["frase_confirmacao"],
        "proximo_passo": (
            f"NADA foi executado. Peça ao usuário para abrir um terminal, rodar servidor_mcp\\aprovar.bat {pedido['id']} "
            f"e digitar a frase de confirmação (\"{resumo['frase_confirmacao']}\"). Só chame executar_pedido_aprovado "
            "depois que ele disser que aprovou."
        ),
    }


@mcp.tool(annotations=SO_LEITURA)
def status_pedido(pedido_id: str) -> dict:
    """Mostra o estado de um pedido: pendente, aprovada, executando, usada, recusada, expirada, invalidada ou indeterminada."""
    with _erros():
        p = aprovacoes.carregar(pedido_id)
    return {
        "pedido_id": p["id"], "tipo": p["tipo"], "estado": p["estado"], "titulo": p["resumo"].get("titulo"),
        "expira_em": aprovacoes.iso(p["expira_em"]), "aprovada_em": aprovacoes.iso(p["aprovada_em"]),
        "aprovador": p["aprovador"], "resultado": p["resultado"], "motivo": p["motivo"],
    }


@mcp.tool(annotations=EXECUTA)
def executar_pedido_aprovado(pedido_id: str) -> dict:
    """EXECUTA um pedido que o USUÁRIO já aprovou no terminal. Vale uma única vez. Recusa pedidos pendentes, vencidos ou alterados."""
    cfg = _config()
    with _erros():
        p = aprovacoes.reservar_execucao(pedido_id)
    pid, par = p["id"], p["parametros"]
    try:
        api = _api(cfg)
        if p["tipo"] == "migracao":
            todos = api.modulos(par["conjunto"])
            plano = migracao.montar_plano(todos, par["modulos"])
            if plano["ordem_final"] != par["ordem_final"] or migracao.hash_comandos(plano["_itens_finais"]) != par["hash_comandos"]:
                aprovacoes.invalidar(pid, "Os itens ou os SQLs do migrador mudaram depois da aprovação.")
                raise ErroUsuario("Os itens ou os SQLs do migrador mudaram depois da aprovação. Faça um novo pedido.")
            depara = {}
            for chave in ("clientes", "produtos"):
                arq = par["depara"].get(f"{chave}_arquivo")
                if arq:
                    texto, sha = migracao.ler_depara(arq)
                    if sha != par["depara"][f"{chave}_sha"]:
                        aprovacoes.invalidar(pid, f"O arquivo de códigos de {chave} mudou depois da aprovação.")
                        raise ErroUsuario(f"O arquivo de códigos de {chave} mudou depois da aprovação. Faça um novo pedido.")
                    depara[f"depara_{chave}"] = texto
            _auditar(par["destino"], "EXECUTAR", f"{pid} {par['conjunto']} {par['modulos']} simular={par['simular']}")
            r = api.migrar(_payload_migracao(cfg, par, depara))
            aprovacoes.concluir(pid, {"exec_id": r["exec_id"]})
            return {"pedido_id": pid, "exec_id": r["exec_id"], "simulacao": par["simular"], "itens": plano["ordem_final"],
                    "proximo_passo": "Acompanhe com status_execucao(exec_id) até concluir ou dar erro."}
        _destino(cfg, par["destino"])
        cd = cfg["conexoes"][par["destino"]]
        _auditar(par["destino"], "EXECUTAR", f"{pid} ajuste_codigos clientes={par['clientes']} produtos={par['produtos']}")
        r = api.ajustar_codigos({"postgres": migracao.conexao_postgres(par["destino"], cd),
                                 "clientes": par["clientes"], "produtos": par["produtos"]})
        aprovacoes.concluir(pid, {"ajuste_id": r["ajuste_id"]})
        return {"pedido_id": pid, "ajuste_id": r["ajuste_id"],
                "proximo_passo": "Acompanhe com status_ajuste_codigos(ajuste_id)."}
    except ErroUsuario:
        raise
    except migracao.ErroMigrador as e:
        if e.nao_iniciou:
            aprovacoes.liberar(pid)
            raise ErroUsuario(f"{e} Nada foi iniciado; o pedido continua aprovado e pode ser tentado de novo.") from e
        aprovacoes.marcar_indeterminada(pid, str(e))
        raise ErroUsuario(f"{e} Não sei se a execução começou: confira o migrador antes de qualquer nova ação.") from e
    except conexoes.ErroConfig as e:
        aprovacoes.liberar(pid)
        raise ErroUsuario(f"{e} Nada foi iniciado; o pedido continua aprovado.") from e
    except Exception as e:  # inesperado: não arrisca repetir a execução
        aprovacoes.marcar_indeterminada(pid, f"{type(e).__name__}: {e}")
        raise ErroUsuario(f"Erro inesperado ({type(e).__name__}). Confira o migrador antes de qualquer nova ação.") from e


@mcp.tool(annotations=SO_LEITURA)
def status_execucao(exec_id: str, desde: int = 0) -> dict:
    """Acompanha uma migração/simulação: situação de cada item (lidos, inseridos, erros, tempo) e as últimas linhas do log."""
    cfg = _config()
    with _erros():
        return migracao.resumir_status(_api(cfg).status(exec_id, desde))


@mcp.tool(annotations=SO_LEITURA)
def status_ajuste_codigos(ajuste_id: str, desde: int = 0) -> dict:
    """Acompanha um ajuste de códigos (situação, log, resultado e arquivos gerados)."""
    cfg = _config()
    with _erros():
        s = _api(cfg).status_ajuste(ajuste_id, desde)
    log = s.get("log", [])
    return {"status": s.get("status"), "erro": s.get("erro"), "resultado": s.get("resultado"),
            "log": log[-60:], "total_log": s.get("total_log")}



if __name__ == "__main__":
    print("MCP migrador-cm iniciado (stdio): leitura livre, migração com aprovação", file=sys.stderr)
    mcp.run()
