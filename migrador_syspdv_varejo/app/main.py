"""
Migrador SysPDV (Firebird) -> VarejoFacil (PostgreSQL), em Python.

Uma tela so: conexoes no topo e, abaixo, os checkboxes - um para cada pasta em
comandos/ (ver app/motor.py). Senhas nunca sao gravadas em disco: chegam em
cada requisicao.
"""
from __future__ import annotations

import os
import string
import json
import threading
import time
from pathlib import Path

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

from . import docker_firebird, motor
from .firebird_conexao import (ConexaoServidor, aviso_permissao, conectar_servidor, diagnostico,
                               localizar_fbclient, mensagem_amigavel)

RAIZ = Path(__file__).resolve().parent.parent
VERSAO = "2026.11.41"
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
    from app import senha_postgres
    if not c.password:
        raise HTTPException(400, "Informe a senha do PostgreSQL.")
    try:
        con = psycopg.connect(host=c.host, port=c.port, dbname=c.dbname, user=c.user,
                              password=c.password, connect_timeout=10,
                              application_name="migrador_syspdv_varejo")
    except Exception as e:
        t = str(e)
        if "password authentication failed" in t:
            t = "Usuário ou senha do PostgreSQL incorretos."
        elif "no password supplied" in t:
            t = "Informe a senha do PostgreSQL."
        elif "role" in t and "does not exist" in t:
            t = f"O usuário '{c.user}' não existe no PostgreSQL."
        elif "does not exist" in t:
            t = f"O banco '{c.dbname}' não existe no PostgreSQL."
        elif "Connection refused" in t:
            t = f"Não consegui conectar no PostgreSQL em {c.host}:{c.port}. O serviço está rodando?"
        raise HTTPException(400, t)
    try:
        senha_postgres.validar(con, c.user, c.password)   # confere a senha mesmo com pg_hba em "trust"
    except senha_postgres.SenhaInvalida as e:
        con.close()
        raise HTTPException(400, str(e))
    return con


@app.get("/saude")
def saude():
    """Usado pelo iniciar-app para saber se o servidor na porta e ESTE projeto."""
    return {"app": "migrador_syspdv_varejo", "pasta": str(RAIZ), "versao": VERSAO,
            "sistema": "windows" if os.name == "nt" else "linux"}


@app.get("/arquivos")
def navegar_arquivos(caminho: str = "", tipo: str = "firebird"):
    """Navegador de pastas do botao Procurar: lista pastas e os arquivos do tipo pedido
    (firebird: .fdb/.gdb; bak; mdf; ldf). O servidor so atende 127.0.0.1 (so na propria maquina)."""
    extensoes = {"firebird": (".fdb", ".gdb"), "firebird_validar": (".fdb", ".gdb", ".gbk", ".fbk"),
                 "bak": (".bak",), "mdf": (".mdf",), "ldf": (".ldf",)}.get(tipo)
    if not extensoes:
        raise HTTPException(400, "Tipo de arquivo inválido.")
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
    # sem cache: depois de atualizar o migrador, o navegador sempre mostra a tela da versao nova
    return HTMLResponse((RAIZ / "static" / "index.html").read_text(encoding="utf-8"),
                        headers={"Cache-Control": "no-store, max-age=0", "Pragma": "no-cache"})


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
def listar_modulos(conjunto: str = "inicial"):
    """Itens da aba "Migracao Inicial" (comandos/) ou "Migracao Virada" (comandos_virada/)."""
    try:
        return [m.para_dict() for m in motor.descobrir_conjunto(conjunto)]
    except ValueError as e:
        raise HTTPException(400, str(e))


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
    conjunto: str = "inicial"                # aba: "inicial" ou "virada"
    depara_clientes: str | None = None       # virada: conteudo do arquivo de codigos de clientes (CSV)
    depara_produtos: str | None = None       # virada: conteudo do arquivo de codigos de produtos (CSV)
    firebird: Firebird | None = None
    sqlserver: SqlServer | None = None
    postgres: Postgres
    modulos: list[str]
    simular: bool = True
    opcoes: dict = {}   # ex.: {"fora_de_linha": false, "movimentacao": true, "movimentacao_data": "2025-01-01"}


@app.post("/migrar")
def migrar(req: MigrarIn):
    if any(e["status"] == "em_andamento" for e in EXECUCOES.values()):
        raise HTTPException(409, "Já existe uma migração em andamento.")
    try:
        lista = motor.descobrir_conjunto(req.conjunto)
    except ValueError as e:
        raise HTTPException(400, str(e))
    depara = None
    if req.conjunto == "virada" and (req.depara_clientes or req.depara_produtos):
        from app import virada
        try:
            mapas = {}
            if req.depara_clientes:
                mapas["cliente"] = virada.ler_arquivo(req.depara_clientes, "cliente")
            if req.depara_produtos:
                mapas["produto"] = virada.ler_arquivo(req.depara_produtos, "produto")
        except virada.ArquivoInvalido as e:
            raise HTTPException(400, str(e))
        depara = virada.Depara(mapas)
    todos = {m.id: m for m in lista}
    faltando = [i for i in req.modulos if i not in todos or todos[i].automatico_com_grupo or todos[i].automatico_sempre or todos[i].automatico_com_itens]
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
              "modulos": {}, "erro": None, "inicio_ts": time.time(), "duracao_total": None,
              "banco": req.postgres.dbname, "arquivos_virada": [], "conjunto": req.conjunto}
    EXECUCOES[exec_id] = estado

    def rodar():
        try:
            opcoes = motor.valores_opcoes(lista, req.opcoes)   # padrao vem de todos os itens
            estado["log"].append(f"Migração {'VIRADA' if req.conjunto == 'virada' else 'INICIAL'} | "
                                 f"origem: {'SQL Server' if dialeto == 'sqlserver' else 'Firebird'}")
            if opcoes:
                estado["log"].append("Opções: " + ", ".join(
                    f"{k}={v}" if k.endswith("_data") else f"{k}={'sim' if v else 'não'}" for k, v in opcoes.items()
                    if not (k.endswith("_data") and not opcoes.get(k[:-5]))))
            if req.conjunto == "virada" and depara is None:
                estado["log"].append("Virada SEM arquivo de codigos: os itens rodam como na migracao inicial.")
            motor.executar(selecionados, con_fb, con_pg, req.simular, estado, opcoes, dialeto, depara)
            falhou = any(r["status"] == "erro" for r in estado["modulos"].values())
            estado["status"] = "erro" if falhou else "concluido"
            if not req.simular and not falhou:
                _registrar_migracao(req, opcoes)
        except Exception as e:
            estado.update(status="erro", erro=str(e))
            estado["log"].append(f"ERRO: {e}")
        finally:
            con_fb.close()
            con_pg.close()
            estado["duracao_total"] = round(time.time() - estado["inicio_ts"], 1)
            estado["log"].append(f"Tempo total da migração: {motor.formatar_duracao(estado['duracao_total'])}")

    threading.Thread(target=rodar, daemon=True).start()
    return {"exec_id": exec_id}


# ------------------------------------------------------------------ relatorios ---
# O menu Relatorios so aparece depois que uma MIGRACAO INICIAL termina. O registro fica em
# reports/ultima_migracao.json (vale tambem depois de fechar e abrir o migrador).
ARQ_ULTIMA = motor.PASTA_RELATORIOS / "ultima_migracao.json"


def _registrar_migracao(req, opcoes: dict) -> None:
    try:
        anterior = json.loads(ARQ_ULTIMA.read_text(encoding="utf-8")) if ARQ_ULTIMA.exists() else {}
    except Exception:
        anterior = {}
    dados = {"banco": req.postgres.dbname, "conjunto": req.conjunto, "origem_tipo": req.origem_tipo,
             "data": time.strftime("%d/%m/%Y %H:%M"), "versao": VERSAO, "opcoes": opcoes,
             "inicial_concluida": bool(anterior.get("inicial_concluida")) or req.conjunto == "inicial"}
    ARQ_ULTIMA.parent.mkdir(parents=True, exist_ok=True)
    ARQ_ULTIMA.write_text(json.dumps(dados, ensure_ascii=False, indent=2), encoding="utf-8")


@app.get("/relatorios/estado")
def relatorios_estado():
    try:
        d = json.loads(ARQ_ULTIMA.read_text(encoding="utf-8")) if ARQ_ULTIMA.exists() else {}
    except Exception:
        d = {}
    return {"disponivel": bool(d.get("inicial_concluida")), **d}


class FormularioIn(BaseModel):
    origem_tipo: str = "firebird"
    firebird: Firebird | None = None
    sqlserver: SqlServer | None = None
    postgres: Postgres
    troca_produtos: bool | None = None
    troca_clientes: bool | None = None
    nome_cliente: str | None = None
    analista: str | None = None


@app.post("/relatorios/formulario")
def gerar_formulario(req: FormularioIn):
    """Formulario de validacao (modelo da Casa Magalhaes) preenchido com SysPDV x VarejoFacil + as respostas."""
    from app import formulario
    est = relatorios_estado()
    if not est["disponivel"]:
        raise HTTPException(400, "O formulário fica disponível depois que uma migração inicial termina.")
    try:
        if req.origem_tipo == "sqlserver":
            if not req.sqlserver:
                raise HTTPException(400, "Informe a conexão do SQL Server em Conexões.")
            con_o = _conectar_sqlserver(req.sqlserver)
        else:
            if not req.firebird:
                raise HTTPException(400, "Informe a conexão do Firebird em Conexões.")
            con_o = conectar_servidor(ConexaoServidor(**req.firebird.model_dump()))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(400, "Origem: " + mensagem_amigavel(e))
    con_pg = _pg(req.postgres)
    pasta = motor.PASTA_RELATORIOS / "relatorios"
    pasta.mkdir(parents=True, exist_ok=True)
    sim_nao = lambda v: "—" if v is None else ("Sim" if v else "Não")
    try:
        nome = formulario.gerar(con_o, con_pg, req.origem_tipo, est.get("opcoes") or {}, est.get("conjunto") or "inicial",
                                pasta, VERSAO, req.postgres.dbname, log=lambda x: None,
                                respostas={"Nome Cliente": (req.nome_cliente or "").strip(),
                                           "Analista de Migração": (req.analista or "").strip(),
                                           "Mudou Codigo Produto": sim_nao(req.troca_produtos),
                                           "Mudou Codigo Cliente": sim_nao(req.troca_clientes)})
    finally:
        for c in (con_o, con_pg):
            try:
                c.close()
            except Exception:
                pass
    if not nome:
        raise HTTPException(500, "Não consegui gerar o formulário (falta a biblioteca python-docx? rode de novo o instalador).")
    from urllib.parse import quote
    return {"arquivo": nome.split("/")[-1], "url": f"/download/relatorios/{quote(nome)}"}


class RelatorioPadraoIn(BaseModel):
    postgres: Postgres


@app.post("/relatorios/padrao")
def gerar_relatorio_padrao(req: RelatorioPadraoIn):
    """Relatorio padrao do kit-migracao: as tres listagens em CSV do banco VarejoFacil (+ .zip com as tres)."""
    from urllib.parse import quote
    from app import relatorio_padrao
    if not relatorios_estado()["disponivel"]:
        raise HTTPException(400, "Os relatórios ficam disponíveis depois que uma migração inicial termina.")
    con_pg = _pg(req.postgres)
    try:
        r = relatorio_padrao.gerar(con_pg, motor.PASTA_RELATORIOS / "relatorios", req.postgres.dbname)
    finally:
        con_pg.close()
    base = f"/download/relatorios/{quote(r['pasta'])}/"
    for a in r["arquivos"]:
        a["url"] = base + quote(a["nome"]) if a["linhas"] is not None else None
    return {"arquivos": r["arquivos"], "zip": r["zip"], "zip_url": base + quote(r["zip"])}


# ------------------------------------------------- consultar / ajustar codigos ---
class CodigosIn(BaseModel):
    postgres: Postgres
    clientes: bool = False
    produtos: bool = False


def _quais(req: CodigosIn) -> list[str]:
    quais = [q for q, marcado in (("clientes", req.clientes), ("produtos", req.produtos)) if marcado]
    if not quais:
        raise HTTPException(400, "Marque Clientes e/ou Produtos.")
    return quais


@app.post("/codigos/consultar")
def consultar_codigos(req: CodigosIn):
    """Previa: quantos clientes/produtos tem codigo >= 999999 (nada e alterado)."""
    from app.codigos import ajuste
    quais = _quais(req)
    con = _pg(req.postgres)
    try:
        return ajuste.consultar(con, quais)
    except Exception as e:
        raise HTTPException(400, f"Erro ao consultar: {e}")
    finally:
        con.close()


AJUSTES: dict[str, dict] = {}


@app.post("/codigos/ajustar")
def ajustar_codigos(req: CodigosIn):
    """Roda os scripts do kit-migracao (ajusta_cliente.sql / ajusta_produto.sql) em segundo plano,
    numa transacao so, e gera as planilhas. A tela acompanha o log ao vivo por /codigos/status."""
    from app.codigos import ajuste
    if any(e["status"] == "em_andamento" for e in EXECUCOES.values()):
        raise HTTPException(409, "Há uma migração em andamento: espere terminar para ajustar os códigos.")
    if any(a["status"] == "em_andamento" for a in AJUSTES.values()):
        raise HTTPException(409, "Já há um ajuste de códigos em andamento.")
    quais = _quais(req)
    con = _pg(req.postgres)
    aj_id = motor.novo_id()
    estado = {"status": "em_andamento", "log": [], "resultado": None, "erro": None,
              "progresso": {"tipos": {}}, "inicio_ts": time.time(), "duracao": None}
    AJUSTES[aj_id] = estado

    def rodar():
        try:
            estado["resultado"] = ajuste.ajustar(con, quais, req.postgres.dbname, estado["log"].append, estado["progresso"])
            estado["status"] = "concluido"
        except Exception as e:
            estado["erro"] = ("O ajuste falhou e foi DESFEITO por inteiro (o banco ficou como estava). "
                              f"Motivo: {str(e).splitlines()[0]}")
            estado["log"].append("ERRO: " + estado["erro"])
            estado["status"] = "erro"
        finally:
            estado["duracao"] = round(time.time() - estado["inicio_ts"], 1)
            con.close()

    threading.Thread(target=rodar, daemon=True).start()
    return {"ajuste_id": aj_id}


# ------------------------------------------------------ validacao de integridade ---
class ValidacaoIn(BaseModel):
    origem_tipo: str = "firebird"            # "firebird" ou "sqlserver"
    firebird: Firebird | None = None
    sqlserver: SqlServer | None = None
    sqlserver_modo: str = "banco"            # "banco" (DBCC CHECKDB), "bak" (RESTORE VERIFYONLY) ou "mdf"
    caminho_bak: str | None = None           # caminho do .bak NO SERVIDOR SQL Server
    caminho_mdf: str | None = None           # "mdf": arquivos fisicos NO SERVIDOR SQL Server (anexa temporario)
    caminho_ldf: str | None = None           #        LDF opcional (sem ele o log e recriado)
    confirmo_copia: bool = False             # "mdf": o usuario confirmou que sao COPIAS dos arquivos
    opcoes: dict = {}                        # firebird: {"servidor", "tabelas", "modo": auto|local|docker, "container"}


VALIDACOES: dict[str, dict] = {}


@app.post("/validacao/iniciar")
def iniciar_validacao(req: ValidacaoIn):
    """Valida a integridade do banco do SysPDV (nada e gravado nele). Roda em segundo plano."""
    from app import validacao
    if any(v["status"] == "em_andamento" for v in VALIDACOES.values()):
        raise HTTPException(409, "Já há uma validação em andamento.")
    if req.origem_tipo == "sqlserver":
        if not req.sqlserver:
            raise HTTPException(400, "Informe a conexão do SQL Server em Conexões.")
        from app.sqlserver_conexao import ConexaoSqlServer
        c = ConexaoSqlServer(**req.sqlserver.model_dump())
        if req.sqlserver_modo == "bak":
            if not (req.caminho_bak or "").strip():
                raise HTTPException(400, "Informe o caminho do arquivo .bak (no servidor SQL Server).")
            alvo = lambda e: validacao.validar_sqlserver_bak(c, req.caminho_bak.strip(), e)
        elif req.sqlserver_modo == "mdf":
            if not (req.caminho_mdf or "").strip():
                raise HTTPException(400, "Informe o caminho do arquivo .MDF (no servidor SQL Server).")
            if not req.confirmo_copia:
                raise HTTPException(400, "Confirme que está usando uma CÓPIA dos arquivos MDF/LDF: ao anexar, o SQL "
                                         "Server pode atualizar a versão deles.")
            alvo = lambda e: validacao.validar_sqlserver_mdf(c, req.caminho_mdf.strip(), (req.caminho_ldf or "").strip(), e)
        else:
            if not c.banco:
                raise HTTPException(400, "Informe o banco do SQL Server em Conexões.")
            alvo = lambda e: validacao.validar_sqlserver_banco(c, e)
    else:
        if not req.firebird or not req.firebird.caminho:
            raise HTTPException(400, "Informe o banco Firebird (.FDB) em Conexões.")
        c = ConexaoServidor(**req.firebird.model_dump())
        alvo = lambda e: validacao.validar_firebird(c, req.opcoes or {}, e)
    vid = motor.novo_id()
    estado = validacao._novo_estado()
    VALIDACOES[vid] = estado
    threading.Thread(target=alvo, args=(estado,), daemon=True).start()
    return {"validacao_id": vid}


@app.post("/validacao/reparar")
def reparar_banco(req: ValidacaoIn):
    """Repara um .FDB corrompido (mend -> backup -ig -> restore em ARQUIVO NOVO). Exige confirmar a copia."""
    from app import validacao
    if any(v["status"] == "em_andamento" for v in VALIDACOES.values()):
        raise HTTPException(409, "Já há uma validação ou reparo em andamento.")
    if not req.firebird or not req.firebird.caminho:
        raise HTTPException(400, "Informe o banco Firebird (.FDB) a reparar.")
    # a confirmacao de copia so e exigida se o migrador nao conseguir fazer a copia de trabalho (ver reparar_firebird)
    c = ConexaoServidor(**req.firebird.model_dump())
    vid = motor.novo_id()
    estado = validacao._novo_estado()
    VALIDACOES[vid] = estado
    threading.Thread(target=validacao.reparar_firebird, args=(c, req.opcoes or {}, estado), daemon=True).start()
    return {"validacao_id": vid}


@app.get("/validacao/status/{vid}")
def status_validacao(vid: str, desde: int = 0):
    estado = VALIDACOES.get(vid)
    if not estado:
        raise HTTPException(404, "Validação não encontrada.")
    duracao = estado["duracao"] if estado["duracao"] is not None else round(time.time() - estado["inicio_ts"], 1)
    return {**{k: v for k, v in estado.items() if k != "log"}, "duracao": duracao,
            "log": estado["log"][desde:], "total_log": len(estado["log"])}


@app.get("/codigos/status/{aj_id}")
def status_ajuste(aj_id: str, desde: int = 0):
    estado = AJUSTES.get(aj_id)
    if not estado:
        raise HTTPException(404, "Ajuste não encontrado.")
    tipos = (estado.get("progresso") or {}).get("tipos", {})
    pct = round(sum(t["pct"] for t in tipos.values()) / len(tipos), 1) if tipos else 0
    if estado["status"] == "concluido":
        pct = 100
    tempo = estado.get("duracao")
    if tempo is None and estado.get("inicio_ts"):
        tempo = round(time.time() - estado["inicio_ts"], 1)
    return {"status": estado["status"], "log": estado["log"][desde:], "total_log": len(estado["log"]),
            "resultado": estado["resultado"], "erro": estado["erro"],
            "progresso": {"pct": pct, "tempo": tempo, "tipos": tipos}}


@app.get("/codigos/arquivo/{pasta}/{arquivo}")
def baixar_codigos(pasta: str, arquivo: str):
    from app.codigos import ajuste
    caminho = (ajuste.PASTA_ARQUIVOS / pasta / arquivo).resolve()
    if ajuste.PASTA_ARQUIVOS.resolve() not in caminho.parents or not caminho.exists():
        raise HTTPException(404, "Arquivo não encontrado.")
    return FileResponse(caminho, filename=arquivo, media_type="text/csv")


@app.get("/status/{exec_id}")
def status(exec_id: str, desde: int = 0):
    estado = EXECUCOES.get(exec_id)
    if estado is None:
        raise HTTPException(404, "execução não encontrada")
    agora = time.time()
    modulos = {}
    for k, m in estado["modulos"].items():          # o item rodando mostra o tempo decorrido ate agora
        m = dict(m)
        if m["status"] == "rodando" and m.get("inicio_ts"):
            m["duracao"] = round(agora - m["inicio_ts"], 1)
        modulos[k] = m
    total = estado["duracao_total"]
    if total is None:
        total = round(agora - estado["inicio_ts"], 1)
    return {**{k: v for k, v in estado.items() if k not in ("log", "modulos")}, "modulos": modulos,
            "tempo_total": total, "log": estado["log"][desde:], "total_log": len(estado["log"])}


@app.get("/download/{exec_id}/{arquivo:path}")
def download(exec_id: str, arquivo: str):
    caminho = (motor.PASTA_RELATORIOS / exec_id / arquivo).resolve()
    if motor.PASTA_RELATORIOS.resolve() not in caminho.parents or not caminho.is_file():
        raise HTTPException(404, "relatório não encontrado")
    # Relatorios (formulario, relatorio padrao) baixam com o proprio nome; os da migracao levam o id da execucao
    nome = caminho.name if exec_id == "relatorios" else f"{exec_id}_{arquivo}"
    return FileResponse(caminho, filename=nome)
