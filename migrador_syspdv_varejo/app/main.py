"""
Migrador SysPDV (Firebird) -> VarejoFacil (PostgreSQL), em Python.

Uma tela so: conexoes no topo e, abaixo, os checkboxes - um para cada pasta em
comandos/ (ver app/motor.py). Senhas nunca sao gravadas em disco: chegam em
cada requisicao.
"""
from __future__ import annotations

import os
import string
import threading
import time
from datetime import datetime
from pathlib import Path

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

from . import docker_firebird, motor
from .firebird_conexao import (ConexaoServidor, aviso_permissao, conectar_servidor, diagnostico,
                               localizar_fbclient, mensagem_amigavel)

RAIZ = Path(__file__).resolve().parent.parent
VERSAO = "2026.10.25"
app = FastAPI(title="Migrador SysPDV -> VarejoFacil")
EXECUCOES: dict[str, dict] = {}


class Firebird(BaseModel):
    host: str = "localhost"
    porta: int = 3050
    caminho: str
    usuario: str = "SYSDBA"
    senha: str = ""
    charset: str = "WIN1252"
    fbclient: str | None = None
    modo: str = "local"  # local | docker
    pasta_host: str | None = None
    pasta_container: str | None = None


class Postgres(BaseModel):
    host: str = "localhost"
    port: int = 5432
    dbname: str
    user: str = "postgres"
    password: str = ""


def _pg(c: Postgres):
    try:
        return psycopg.connect(host=c.host, port=c.port, dbname=c.dbname, user=c.user,
                               password=c.password, connect_timeout=10,
                               application_name="migrador_syspdv_varejo")
    except Exception as e:
        t = str(e)
        if "password authentication failed" in t:
            t = "PostgreSQL recusou usuário ou senha."
        elif "does not exist" in t:
            t = f"O banco '{c.dbname}' não existe no PostgreSQL."
        elif "Connection refused" in t:
            t = f"Não consegui conectar no PostgreSQL em {c.host}:{c.port}. O serviço está rodando?"
        raise HTTPException(400, t)


@app.get("/saude")
def saude():
    """Usado pelo iniciar-app para saber se o servidor na porta e ESTE projeto."""
    return {"app": "migrador_syspdv_varejo", "pasta": str(RAIZ), "versao": VERSAO,
            "sistema": "windows" if os.name == "nt" else "linux"}


@app.get("/arquivos")
def navegar_arquivos(caminho: str = ""):
    """Navegador de pastas do botao Procurar (aba Windows): lista pastas e bancos .fdb/.gdb.
    O servidor so atende 127.0.0.1, entao isto so e acessivel na propria maquina."""
    extensoes = (".fdb", ".gdb")
    if not caminho:
        if os.name == "nt":   # Windows: comeca pelas unidades (C:, D: ...)
            unidades = [f"{letra}:\\" for letra in string.ascii_uppercase if os.path.exists(f"{letra}:\\")]
            return {"caminho": "", "pai": None,
                    "itens": [{"nome": u, "tipo": "pasta", "caminho": u} for u in unidades]}
        caminho = str(Path.home())
    pasta = Path(caminho)
    if not pasta.is_dir():
        pasta = pasta.parent if pasta.parent.is_dir() else Path.home()
    try:
        entradas = sorted(pasta.iterdir(), key=lambda e: (not e.is_dir(), e.name.lower()))
    except PermissionError:
        raise HTTPException(403, f"Sem permissão para abrir {pasta}")
    itens = []
    for e in entradas:
        if e.name.startswith((".", "$")):
            continue
        try:
            if e.is_dir():
                itens.append({"nome": e.name, "tipo": "pasta", "caminho": str(e)})
            elif e.suffix.lower() in extensoes:
                itens.append({"nome": e.name, "tipo": "arquivo", "caminho": str(e)})
        except OSError:
            continue
    if pasta.parent != pasta:
        pai = str(pasta.parent)
    else:
        pai = "" if os.name == "nt" else None   # na raiz do Windows, volta para a lista de unidades
    return {"caminho": str(pasta), "pai": pai, "itens": itens}


@app.get("/", response_class=HTMLResponse)
def index():
    return (RAIZ / "static" / "index.html").read_text(encoding="utf-8")


# --------------------------------------------------------------- conexoes ---
@app.post("/conexoes/firebird/testar")
def testar_firebird(req: Firebird):
    c = ConexaoServidor(**req.model_dump())
    try:
        caminho_servidor = c.caminho_servidor
        client = localizar_fbclient(c.fbclient)
        con = conectar_servidor(c)
    except Exception as e:
        raise HTTPException(400, mensagem_amigavel(e))
    try:
        info = diagnostico(con)
    finally:
        con.close()
    if (aviso := aviso_permissao(c.caminho)):
        info["avisos"].append(aviso)
    if info["charset_banco"] not in ("NONE", c.charset):
        info["avisos"].append(f"O banco é {info['charset_banco']} e a conexão usa {c.charset}.")
    info.update(fbclient=client or "(padrão do sistema)", caminho_servidor=caminho_servidor)
    return info


@app.post("/conexoes/firebird/traduzir")
def traduzir(req: Firebird):
    try:
        return {"caminho_servidor": ConexaoServidor(**req.model_dump()).caminho_servidor}
    except ValueError as e:
        raise HTTPException(400, str(e))


class DockerIn(BaseModel):
    container: str | None = None
    caminho_fdb: str | None = None


@app.post("/conexoes/docker/detectar")
def detectar_docker(req: DockerIn):
    try:
        containers = docker_firebird.listar_containers_firebird()
        if not containers:
            raise HTTPException(404, "Nenhum container do Firebird em execução.")
        nomes = [c["nome"] for c in containers]
        info = docker_firebird.inspecionar(req.container if req.container in nomes else nomes[0],
                                           req.caminho_fdb or None)
    except docker_firebird.ErroDocker as e:
        raise HTTPException(400, str(e))
    avisos = []
    if not info["porta_publicada"]:
        avisos.append("A porta 3050 não está publicada; usando o IP interno do container (só Linux).")
    if not info["parece_2_5"]:
        avisos.append(f"A imagem '{info['imagem']}' não indica Firebird 2.5.")
    if not info["montagens"]:
        avisos.append("O container não tem volume mapeado: o .FDB precisa estar dentro dele.")
    return {"containers": containers, **info, "avisos": avisos}


@app.post("/conexoes/postgres/testar")
def testar_postgres(req: Postgres):
    con = _pg(req)
    try:
        versao, encoding = con.execute(
            "SELECT current_setting('server_version'), current_setting('server_encoding')").fetchone()
        tabelas = {t: con.execute("SELECT to_regclass(%s) IS NOT NULL", (t,)).fetchone()[0]
                   for t in ("secao", "grupo_produto", "subgrupo_produto", "produto", "pessoa")}
    finally:
        con.close()
    avisos = [] if versao.startswith("15") else [f"Esperado PostgreSQL 15; o servidor é {versao}."]
    if not any(tabelas.values()):
        avisos.append("Nenhuma tabela do VarejoFacil encontrada: confira se é o banco certo.")
    return {"versao": versao, "encoding": encoding, "tabelas": tabelas, "avisos": avisos}


# ---------------------------------------------------------------- modulos ---
@app.get("/modulos")
def listar_modulos():
    return [m.para_dict() for m in motor.descobrir()]


# --------------------------------------------------------------- migracao ---
class SqlServer(BaseModel):
    host: str = "localhost"
    porta: int = 1433
    instancia: str | None = None
    banco: str = ""
    usuario: str = "sa"
    senha: str = ""
    driver: str | None = None
    string_odbc: str | None = None


def _conectar_sqlserver(req: SqlServer):
    from app import sqlserver_conexao as sq
    return sq.conectar(sq.ConexaoSqlServer(**req.model_dump()))


@app.post("/conexoes/sqlserver/testar")
def testar_sqlserver(req: SqlServer):
    from app import sqlserver_conexao as sq
    try:
        con = _conectar_sqlserver(req)
    except Exception as e:
        raise HTTPException(400, sq.mensagem_amigavel(e))
    try:
        return sq.diagnostico(con)
    finally:
        con.close()


class MigrarIn(BaseModel):
    origem_tipo: str = "firebird"            # "firebird" ou "sqlserver"
    firebird: Firebird | None = None
    sqlserver: SqlServer | None = None
    postgres: Postgres
    modulos: list[str]
    simular: bool = True
    opcoes: dict[str, bool] = {}   # ex.: {"fora_de_linha": false}


@app.post("/migrar")
def migrar(req: MigrarIn):
    if any(e["status"] == "em_andamento" for e in EXECUCOES.values()):
        raise HTTPException(409, "Já existe uma migração em andamento.")
    lista = motor.descobrir()
    todos = {m.id: m for m in lista}
    faltando = [i for i in req.modulos if i not in todos or todos[i].automatico_com_grupo or todos[i].automatico_sempre]
    if faltando or not req.modulos:
        raise HTTPException(400, f"Módulos inválidos: {faltando or 'nenhum marcado'}")
    # ordem das pastas (01_, 02_...) + itens automaticos do grupo (ex.: Ajustes finais de Pessoas)
    selecionados = motor.com_automaticos([todos[i] for i in req.modulos], lista)
    # testa as duas conexoes antes de comecar (erro aparece na hora, nao no meio)
    dialeto = "sqlserver" if req.origem_tipo == "sqlserver" else "firebird"
    try:
        if dialeto == "sqlserver":
            if not req.sqlserver:
                raise HTTPException(400, "Informe a conexão do SQL Server.")
            con_fb = _conectar_sqlserver(req.sqlserver)
        else:
            if not req.firebird:
                raise HTTPException(400, "Informe a conexão do Firebird.")
            con_fb = conectar_servidor(ConexaoServidor(**req.firebird.model_dump()))
    except HTTPException:
        raise
    except Exception as e:
        if dialeto == "sqlserver":
            from app import sqlserver_conexao as sq
            raise HTTPException(400, "SQL Server: " + sq.mensagem_amigavel(e))
        raise HTTPException(400, "Firebird: " + mensagem_amigavel(e))
    con_pg = _pg(req.postgres)

    exec_id = motor.novo_id()
    estado = {"id": exec_id, "status": "em_andamento", "simulacao": req.simular, "log": [],
              "modulos": {}, "erro": None}
    EXECUCOES[exec_id] = estado

    def rodar():
        inicio = datetime.now()
        t0 = time.monotonic()
        estado["log"].append(f"Migração iniciada em {inicio:%d/%m/%Y %H:%M:%S}")
        final, erro = "erro", None
        try:
            opcoes = motor.valores_opcoes(lista, req.opcoes)   # padrao vem de todos os itens
            estado["log"].append(f"Origem: {'SQL Server' if dialeto == 'sqlserver' else 'Firebird'}")
            if opcoes:
                estado["log"].append("Opções: " + ", ".join(f"{k}={'sim' if v else 'não'}" for k, v in opcoes.items()))
            motor.executar(selecionados, con_fb, con_pg, req.simular, estado, opcoes, dialeto)
            falhou = any(r["status"] == "erro" for r in estado["modulos"].values())
            final = "erro" if falhou else "concluido"
        except Exception as e:
            erro = str(e)
            estado["log"].append(f"ERRO: {e}")
        finally:
            con_fb.close()
            con_pg.close()
            # tempo total vai para o log ANTES de mudar o status: a tela para de consultar
            # o log assim que o status deixa de ser "em_andamento"
            estado["duracao"] = round(time.monotonic() - t0, 1)
            situacao = "concluída" if final == "concluido" else "terminou com erro"
            estado["log"].append(f"Migração {situacao} em {datetime.now():%d/%m/%Y %H:%M:%S} — tempo total: "
                                 f"{motor.duracao(estado['duracao'])}")
            estado.update(status=final, erro=erro)

    threading.Thread(target=rodar, daemon=True).start()
    return {"exec_id": exec_id}


@app.get("/status/{exec_id}")
def status(exec_id: str, desde: int = 0):
    estado = EXECUCOES.get(exec_id)
    if estado is None:
        raise HTTPException(404, "execução não encontrada")
    return {**{k: v for k, v in estado.items() if k != "log"},
            "log": estado["log"][desde:], "total_log": len(estado["log"])}


@app.get("/download/{exec_id}/{arquivo}")
def download(exec_id: str, arquivo: str):
    caminho = (motor.PASTA_RELATORIOS / exec_id / arquivo).resolve()
    if motor.PASTA_RELATORIOS.resolve() not in caminho.parents or not caminho.exists():
        raise HTTPException(404, "relatório não encontrado")
    return FileResponse(caminho, filename=f"{exec_id}_{arquivo}")
