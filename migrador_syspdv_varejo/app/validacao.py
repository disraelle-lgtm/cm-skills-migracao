"""
Validacao de integridade do banco do SysPDV (pagina "Validacao de Integridade" da tela).

Nada e gravado no banco validado. Roda em segundo plano; a tela acompanha cada verificacao.

FIREBIRD (o .FDB da conexao de origem):
  1. Conexao e cabecalho: ODS, tamanho de pagina e as transacoes (OIT/OAT/Next). Um intervalo grande
     entre a transacao mais antiga e a proxima indica banco precisando de sweep (fica lento).
  2. Validacao do servidor Firebird, SOMENTE LEITURA (a mesma do "gfix -v -n", pela Services API):
     encontra paginas e registros corrompidos. O detalhe de cada erro fica no firebird.log do servidor.
     No Firebird 2.5 ela pode exigir que ninguem esteja usando o banco.
  3. Leitura completa de cada tabela (todas as linhas): aponta QUAL tabela esta quebrada - e o que
     faria a migracao parar no meio.

SQL SERVER:
  - Banco: estado do banco (ONLINE/SUSPECT...), DBCC CHECKDB (verificacao oficial da Microsoft) e as
    paginas suspeitas registradas pelo SQL Server (msdb.dbo.suspect_pages).
  - Arquivo .bak (caminho no SERVIDOR SQL Server, e ele quem le o arquivo): RESTORE HEADERONLY (de
    que banco e de quando e o backup), RESTORE FILELISTONLY e RESTORE VERIFYONLY (com CHECKSUM quando
    o backup tiver).
  - Arquivos .MDF + .LDF (o banco fisico, caminhos no SERVIDOR SQL Server): le o cabecalho do MDF SEM
    anexar (DBCC CHECKPRIMARYFILE: nome do banco e versao interna), anexa como banco TEMPORARIO
    (MIGRADOR_VALIDACAO_...; sem LDF o log e recriado), roda o DBCC CHECKDB e SEMPRE desanexa no fim.
    ATENCAO: anexar um MDF de versao mais antiga do SQL Server ATUALIZA o arquivo (nao abre mais na
    versao antiga) - por isso a tela exige confirmar que sao COPIAS dos arquivos.
"""
from __future__ import annotations

import re
import time
import traceback

LIMITE_TRANSACOES = 20000      # Next - OIT acima disto: banco precisando de sweep
LOTE = 5000


def _novo_estado() -> dict:
    return {"status": "em_andamento", "veredito": None, "resumo": None, "verificacoes": [], "tabelas": [],
            "banco_validado": None,
            "log": [], "inicio_ts": time.time(), "duracao": None, "erro": None}


def _verificacao(estado, nome) -> dict:
    v = {"nome": nome, "status": "rodando", "detalhe": "", "itens": []}
    estado["verificacoes"].append(v)
    estado["log"].append(f"{nome}...")
    return v


def _fim(estado, v, status, detalhe, itens=None):
    v.update(status=status, detalhe=detalhe)
    if itens:
        v["itens"] = itens
    marca = {"ok": "OK", "aviso": "AVISO", "erro": "ERRO", "ignorado": "IGNORADO"}[status]
    estado["log"].append(f"  {marca}: {detalhe}")


def _concluir(estado, alvo: str = "Banco"):
    st = [v["status"] for v in estado["verificacoes"]]
    if "erro" in st:
        estado["veredito"] = "problemas"
        estado["resumo"] = ("O reparo não terminou: veja os itens em vermelho." if alvo == "Reparo"
                            else "Foram encontrados problemas de integridade: veja os itens em vermelho.")
    elif "aviso" in st:
        estado["veredito"] = "avisos"
        estado["resumo"] = ("Reparo concluído, com avisos: o banco novo foi criado, mas confira os itens em laranja "
                            "(registros perdidos ou tabelas a conferir)." if alvo == "Reparo"
                            else "Não foram encontrados erros de integridade, mas há avisos: veja os itens em laranja.")
    else:
        estado["veredito"] = "integro"
        estado["resumo"] = ("Reparo concluído: banco novo criado e validado." if alvo == "Reparo"
                            else f"{alvo} íntegro: nenhuma verificação encontrou problema.")
    estado["duracao"] = round(time.time() - estado["inicio_ts"], 1)
    estado["status"] = "concluido"
    estado["log"].append(f"Fim: {estado['resumo']} ({estado['duracao']}s)")


def _primeira_linha(erro: Exception) -> str:
    texto = str(erro).replace("\\n", "\n")
    if "[SQL Server]" in texto:                       # pyodbc: "[42000] [Microsoft][ODBC ...][SQL Server]mensagem (3201)"
        texto = texto.split("[SQL Server]")[-1]
    texto = re.sub(r"'?,\s*-?\d+,\s*-?\d+\)\s*$", "", texto.strip())      # fdb: "...', -902, 335544344)"
    linhas = [l.strip(" -") for l in texto.splitlines() if l.strip(" -")]
    uteis = [l for l in linhas if not l.startswith(("SQLCODE", "Cursor.", "Error while", "('", "Unable to perform"))]
    return " | ".join((uteis or linhas)[:3])[:400]


# =============================================================================================== FIREBIRD
LOGS_FIREBIRD = [
    r"C:\Program Files\Firebird\Firebird_2_5\firebird.log",
    r"C:\Program Files (x86)\Firebird\Firebird_2_5\firebird.log",
    r"C:\Program Files\Firebird\Firebird_3_0\firebird.log",
    "/opt/firebird/firebird.log", "/var/log/firebird/firebird3.0.log", "/var/log/firebird/firebird.log",
    "/var/log/firebird2.5/firebird2.5.log",
]


def _erros_no_log(caminho_banco: str, desde: float) -> list[str]:
    """Le o firebird.log (quando o servidor Firebird esta NESTA maquina) e devolve os erros da validacao
    deste banco: ex. "Data page 495 ... is bad in table PRODUTO". Vazio se nao achar o log."""
    import os
    nome = os.path.basename(caminho_banco).lower()
    for arq in LOGS_FIREBIRD:
        try:
            if not os.path.exists(arq) or os.path.getmtime(arq) < desde - 5:
                continue
            with open(arq, "rb") as f:
                f.seek(max(0, os.path.getsize(arq) - 400_000))
                texto = f.read().decode("latin-1", errors="replace")
        except OSError:
            continue
        return _erros_do_texto(texto, nome)
    return []


def _erros_do_texto(texto: str, nome: str) -> list[str]:
    """O log acumula validacoes anteriores: fica so o bloco da ULTIMA validacao deste banco."""
    import os
    ultimo, atual, deste = [], [], False
    for linha in texto.splitlines():
        l = linha.strip()
        if l.lower().startswith("database:"):
            deste = os.path.basename(l.split(":", 1)[1].strip()).lower() == nome
        elif deste and (l.startswith("Error:") or l.startswith("Warning:")):
            atual.append(l)
        elif deste and "Validation finished" in l:
            ultimo, atual = atual + [l], []
    return (ultimo or atual)[-60:]


LOGS_CONTAINER = ["/firebird/log/firebird.log", "/firebird/firebird.log", "/usr/local/firebird/firebird.log",
                  "/opt/firebird/firebird.log", "/var/log/firebird/firebird.log"]


def _erros_no_log_docker(container: str, caminho_container: str) -> list[str]:
    """Firebird em Docker: le o firebird.log de DENTRO do container (docker exec)."""
    import posixpath
    from app import docker_firebird
    for arq in LOGS_CONTAINER:
        try:
            texto = docker_firebird._docker("exec", container, "tail", "-c", "400000", arq, timeout=15)
        except Exception:
            continue
        if texto.strip():
            return _erros_do_texto(texto, posixpath.basename(caminho_container).lower())
    return []


# --------------------------------------------------- onde esta o servidor Firebird: local ou Docker
def _permissao_local(caminho: str) -> list[str]:
    """Linux, Firebird instalado na maquina: o servidor roda com o usuario 'firebird' e precisa LER e
    GRAVAR o .FDB e ATRAVESSAR as pastas ate ele. Devolve os comandos para corrigir (vazio = ok)."""
    import os
    import grp
    import pwd
    try:
        fb = pwd.getpwnam("firebird")
    except KeyError:
        return []                                   # servidor nao roda como 'firebird': nao da para conferir
    grupos = {g.gr_gid for g in grp.getgrall() if "firebird" in g.gr_mem} | {fb.pw_gid}

    def pode(st, bits_dono, bits_grupo, bits_outros):
        if st.st_uid == fb.pw_uid:
            return st.st_mode & bits_dono == bits_dono
        if st.st_gid in grupos:
            return st.st_mode & bits_grupo == bits_grupo
        return st.st_mode & bits_outros == bits_outros

    comandos = []
    pasta = os.path.dirname(os.path.abspath(caminho))
    bloqueadas = []
    while True:
        try:
            if not pode(os.stat(pasta), 0o100, 0o010, 0o001):
                bloqueadas.append(pasta)
        except OSError:
            pass
        pai = os.path.dirname(pasta)
        if pai == pasta:
            break
        pasta = pai
    for b in reversed(bloqueadas):
        comandos.append(f'sudo chmod o+x "{b}"')
    if caminho.lower().endswith((".gbk", ".fbk")):
        # backup: o servidor so le o arquivo, mas CRIA o banco restaurado na mesma pasta
        pasta_bkp = os.path.dirname(os.path.abspath(caminho))
        if not pode(os.stat(pasta_bkp), 0o300, 0o030, 0o003):
            comandos.append(f'sudo chmod o+wx "{pasta_bkp}"')
        if not pode(os.stat(caminho), 0o400, 0o040, 0o004):
            comandos.append(f'sudo chmod o+r "{caminho}"')
        return comandos
    if not pode(os.stat(caminho), 0o600, 0o060, 0o006):
        comandos.append(f'sudo chmod 666 "{caminho}"')
    return comandos


def _resolver_servidor(c, modo: str, container: str | None, estado, v) -> tuple:
    """Decide se o .FDB e aberto pelo Firebird LOCAL ou pelo do DOCKER (traduzindo o caminho).
    Devolve (conexao ajustada, nome do container ou None, itens) ou levanta ValueError com a explicacao."""
    import os
    from dataclasses import replace
    from app import docker_firebird
    itens = []
    info, motivo_docker = None, None
    if modo in ("auto", "docker"):
        try:
            conts = docker_firebird.listar_containers_firebird()
            if conts:
                nomes = [x["nome"] for x in conts]
                info = docker_firebird.inspecionar(container if container in nomes else nomes[0], c.caminho)
            else:
                motivo_docker = "nenhum container do Firebird está rodando"
        except Exception as e:                       # docker nao instalado / sem permissao / parado
            motivo_docker = str(e)
    if info is not None:
        montagem = next((m for m in info["montagens"]
                         if docker_firebird._dentro(c.caminho, m["host"])
                         or c.caminho.replace("\\", "/").startswith(m["container"].rstrip("/") + "/")), None)
        if montagem:
            nova = replace(c, modo="docker", pasta_host=montagem["host"], pasta_container=montagem["container"],
                           host=info["host"], porta=int(info["porta"]))
            itens += [f"Firebird em Docker: container {info['nome']} ({info['imagem']})",
                      f"Pasta compartilhada: {montagem['host']} (computador) = {montagem['container']} (container)",
                      f"Caminho do banco dentro do container: {nova.caminho_servidor}"]
            return nova, info["nome"], itens
        if modo == "docker":
            pastas = "; ".join(f"{m['host']} = {m['container']}" for m in info["montagens"]) or "nenhuma"
            raise ValueError(f"O arquivo não está numa pasta compartilhada com o container {info['nome']} "
                             f"(pastas compartilhadas: {pastas}). Copie o .FDB para uma dessas pastas do computador "
                             "ou informe o caminho de dentro do container.")
    elif modo == "docker":
        raise ValueError(f"Modo Docker escolhido, mas {motivo_docker or 'o Docker não respondeu'}. "
                         "Confira se o container do Firebird está rodando (docker ps).")
    # ---- Firebird instalado nesta maquina
    itens.append("Servidor Firebird em " + f"{c.host}:{c.porta}"
                 + (" (instalado neste computador)" if modo == "local" else ""))
    if os.name != "nt" and c.host in ("localhost", "127.0.0.1") and (modo == "local" or os.path.exists(c.caminho)):
        if not os.path.exists(c.caminho):
            raise ValueError(f"O arquivo {c.caminho} não existe neste computador. Confira o caminho (use o Procurar...). "
                             "Se o Firebird está em Docker, escolha Docker ou Automático com o container rodando.")
        comandos = _permissao_local(c.caminho)
        if comandos:
            raise ValueError("O servidor Firebird (usuário 'firebird') não tem permissão para abrir o arquivo. "
                             "Rode no terminal:\n" + "\n".join(comandos))
    return replace(c, modo="local"), None, itens
def validar_firebird(c, opcoes: dict, estado: dict) -> None:
    """c: firebird_conexao.ConexaoServidor. opcoes: servidor, tabelas, modo (auto|local|docker), container."""
    import fdb
    from app.firebird_conexao import conectar_servidor, mensagem_amigavel
    try:
        # 1) conexao e cabecalho (tambem carrega o fbclient para a Services API)
        v = _verificacao(estado, "Conexão e cabeçalho do banco")
        try:
            c, container, itens_servidor = _resolver_servidor(c, opcoes.get("modo") or "auto", opcoes.get("container"),
                                                               estado, v)
        except ValueError as e:
            _fim(estado, v, "erro", str(e))
            _concluir(estado)
            return
        if c.caminho.lower().endswith((".gbk", ".fbk")):
            # BACKUP (gbak): nao existe "verificar sem restaurar" - a unica forma confiavel e restaurar. Restaura num
            # .FDB novo ao lado do backup e valida o restaurado (que ja fica pronto para a migracao).
            _fim(estado, v, "ok", "Servidor localizado; o arquivo é um backup do Firebird (gbak).", itens_servidor)
            v = _verificacao(estado, "Restaurar o backup num banco novo (gbak -c)")
            backup = c.caminho_servidor
            mod, pasta, nome = _pasta_e_nome(backup)
            novo = mod.join(pasta, f"{nome}_RESTAURADO_{time.strftime('%Y%m%d_%H%M%S')}.FDB")
            linhas = []
            svc = None
            try:
                svc = fdb.services.connect(host=f"{c.host}/{c.porta}", user=c.usuario, password=c.senha)
                svc.restore(backup, novo, replace=0, callback=linhas.append)
                erros = [l for l in linhas if "ERROR" in l.upper()]
                if erros:
                    raise RuntimeError(" | ".join(erros[:3]))
                tabelas_rest = sum(1 for l in linhas if "restoring data for table" in l.lower())
                _fim(estado, v, "ok", f"Backup restaurado ({tabelas_rest} tabelas) em: {novo}",
                     ["O banco restaurado é o que será validado agora — e pode ser usado na migração."])
            except Exception as e:
                texto = str(e).lower()
                dica = ""
                if "permission" in texto or "access" in texto or "operating system" in texto or "i/o error" in texto:
                    dica = (" O servidor Firebird não conseguiu ler o backup ou criar o banco novo na pasta: no Linux, a "
                            f"pasta precisa permitir gravação para o usuário do Firebird (ex.: sudo chmod o+w \"{pasta}\").")
                # apaga o .FDB incompleto que a restauracao com erro deixou (quando o arquivo esta acessivel aqui)
                try:
                    import os
                    from dataclasses import replace as _rep
                    parcial = _arquivo_no_computador(_rep(c, caminho=novo) if c.modo != "docker" else c)
                    if c.modo == "docker" and c.pasta_host and c.pasta_container:
                        pc = c.pasta_container.replace("\\", "/").rstrip("/")
                        nv = novo.replace("\\", "/")
                        parcial = os.path.join(c.pasta_host, *nv[len(pc) + 1:].split("/")) if nv.startswith(pc + "/") else None
                    if parcial and os.path.isfile(parcial):
                        os.remove(parcial)
                        estado["log"].append(f"  arquivo incompleto da restauração apagado: {novo}")
                except Exception:
                    pass
                _fim(estado, v, "erro", f"Não foi possível restaurar o backup: {_primeira_linha(e)}.{dica} Um backup "
                     "que não restaura está danificado ou incompleto: peça um novo backup ao cliente.", linhas[-10:])
                _concluir(estado)
                return
            finally:
                if svc is not None:
                    try:
                        svc.close()
                    except Exception:
                        pass
            from dataclasses import replace as _replace
            c = _replace(c, caminho=novo, modo="local", pasta_host=None, pasta_container=None)
            v = _verificacao(estado, "Conexão e cabeçalho do banco restaurado")
        try:
            con = conectar_servidor(c)
        except Exception as e:
            dica = (" (Docker: o arquivo precisa estar numa pasta compartilhada com o container.)" if container else "")
            _fim(estado, v, "erro", "Não foi possível abrir o banco: " + mensagem_amigavel(e) + dica, itens_servidor)
            _concluir(estado)
            return
        cur = con.cursor()
        cur.execute("SELECT RDB$GET_CONTEXT('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
        versao = cur.fetchone()[0]
        oit, oat, prox = con.oit, con.oat, con.next_transaction
        itens = itens_servidor + [f"Servidor Firebird {versao}", f"ODS {con.ods}, página de {con.page_size} bytes",
                 f"Transações: mais antiga ativa (OAT) {oat}, mais antiga interessante (OIT) {oit}, próxima {prox}"]
        cur.execute("SELECT TRIM(RDB$RELATION_NAME) FROM RDB$RELATIONS "
                    "WHERE COALESCE(RDB$SYSTEM_FLAG, 0) = 0 AND RDB$VIEW_BLR IS NULL "
                    "AND RDB$EXTERNAL_FILE IS NULL ORDER BY 1")
        tabelas = [r[0] for r in cur.fetchall()]
        itens.append(f"{len(tabelas)} tabelas de dados")
        con.close()
        estado["banco_validado"] = c.caminho_servidor      # caminho como o servidor ve (vai para Conexoes)
        if prox - oit > LIMITE_TRANSACOES:
            _fim(estado, v, "aviso", f"Banco abre normalmente, mas há {prox - oit} transações entre a mais antiga "
                 "e a próxima: precisa de sweep (gfix -sweep) - fica lento, não é corrupção.", itens)
        else:
            _fim(estado, v, "ok", "Banco abre normalmente; cabeçalho sem problema.", itens)

        # 2) validacao do servidor (somente leitura)
        v = _verificacao(estado, "Validação do servidor Firebird (somente leitura, como gfix -v -n)")
        if not opcoes.get("servidor", True):
            _fim(estado, v, "ignorado", "Desmarcada nas opções.")
        else:
            try:
                svc = fdb.services.connect(host=f"{c.host}/{c.porta}", user=c.usuario, password=c.senha)
                try:
                    svc.repair(c.caminho_servidor, read_only_validation=1)
                    saida = [l for l in svc.readlines() if l and l.strip()]
                finally:
                    svc.close()
                _fim(estado, v, "ok", "O servidor Firebird validou páginas e registros e não encontrou erros.",
                     saida[:50])
            except Exception as e:
                texto = str(e)
                if "validation errors" in texto.lower():
                    detalhes = (_erros_no_log_docker(container, c.caminho_servidor) if container
                                else _erros_no_log(c.caminho_servidor, estado["inicio_ts"]))
                    onde = ("Detalhes lidos do firebird.log" + (" do container" if container else " deste computador")
                            + " abaixo." if detalhes else "O detalhe de cada erro fica no firebird.log do servidor Firebird.")
                    _fim(estado, v, "erro", "O servidor Firebird encontrou ERROS DE VALIDAÇÃO (páginas ou registros "
                         f"corrompidos). {onde} Faça um backup/restore (gbak) ou peça a correção antes de migrar.",
                         detalhes)
                elif any(k in texto.lower() for k in ("in use", "lock", "shutdown", "exclusive", "secondary server attachments")):
                    _fim(estado, v, "aviso", "O servidor não validou porque o banco está aberto por outras conexões (no "
                         "Firebird 2.5 a validação precisa do banco só para ela). Feche o SysPDV, o IBExpert/DBeaver e "
                         "qualquer migração usando este banco e valide de novo. A leitura das tabelas abaixo continua valendo. "
                         f"({_primeira_linha(e)})")
                elif any(k in texto.lower() for k in ("not authorized", "no permission", "user name and password")):
                    _fim(estado, v, "aviso", "O usuário da conexão não tem permissão para validar pelo serviço do "
                         f"Firebird (use o SYSDBA). ({_primeira_linha(e)})")
                else:
                    _fim(estado, v, "aviso", f"Não foi possível validar pelo serviço do Firebird: {_primeira_linha(e)}")

        # 3) leitura completa de cada tabela
        v = _verificacao(estado, "Leitura completa de cada tabela")
        if not opcoes.get("tabelas", True):
            _fim(estado, v, "ignorado", "Desmarcada nas opções.")
        else:
            estado["tabelas"] = [{"nome": t, "status": "aguardando", "linhas": 0, "mensagem": ""} for t in tabelas]
            con = conectar_servidor(c)
            bloqueado_por = None                      # tabela em que o servidor deu "bugcheck" e bloqueou o banco
            ultimo_erro = None
            for t in estado["tabelas"]:
                t["status"] = "rodando"
                if bloqueado_por:
                    t["status"], t["mensagem"] = "aviso", f"não verificada: o servidor bloqueou o banco depois do erro grave em {bloqueado_por}"
                    continue
                if con is None:                       # o servidor nao aceitou reconectar depois de um erro grave
                    try:
                        con = conectar_servidor(c)
                    except Exception as e:
                        if "bugcheck" in str(e).lower():
                            # o Firebird BLOQUEIA o banco depois de um bugcheck ("can't attach after bugcheck") ate
                            # o servidor ser reiniciado: as tabelas seguintes nao tem como ser lidas agora
                            bloqueado_por = ultimo_erro or "uma tabela"
                            t["status"], t["mensagem"] = "aviso", f"não verificada: o servidor bloqueou o banco depois do erro grave em {bloqueado_por}"
                        else:
                            t["status"] = "erro"
                            t["mensagem"] = "não lida: o servidor Firebird não aceitou nova conexão depois do erro anterior ("
                            t["mensagem"] += _primeira_linha(e) + ")"
                        continue
                try:
                    cur = con.cursor()
                    cur.execute(f'SELECT * FROM "{t["nome"]}"')
                    while True:
                        lote = cur.fetchmany(LOTE)
                        if not lote:
                            break
                        t["linhas"] += len(lote)
                    cur.close()
                    t["status"] = "ok"
                except Exception as e:
                    t["status"] = "erro"
                    t["mensagem"] = _primeira_linha(e)
                    ultimo_erro = t["nome"]
                    estado["log"].append(f"  tabela {t['nome']}: ERRO na linha {t['linhas'] + 1}: {t['mensagem']}")
                    # depois de um erro interno ("consistency check"/"bugcheck") a conexao fica MORTA: nem o
                    # rollback nem o close funcionam. Descarta e reconecta na proxima tabela.
                    con = _descartar(con)
            _descartar(con)
            ruins = [t for t in estado["tabelas"] if t["status"] == "erro"]
            nao_vistas = [t for t in estado["tabelas"] if t["status"] == "aviso"]
            total = sum(t["linhas"] for t in estado["tabelas"])
            if ruins:
                texto = (f"{len(ruins)} de {len(tabelas)} tabela(s) não puderam ser lidas até o fim: "
                         + ", ".join(t["nome"] for t in ruins) + ". A migração dessas tabelas pararia no erro.")
                if nao_vistas:
                    texto += (f" Depois do erro grave em {bloqueado_por}, o servidor Firebird BLOQUEOU o banco (\"can't "
                              f"attach after bugcheck\") e {len(nao_vistas)} tabela(s) ficaram sem verificar: é assim que o "
                              "Firebird se protege. Reinicie o servidor Firebird/container e valide de novo para "
                              "conferir as demais.")
                _fim(estado, v, "erro", texto)
            else:
                _fim(estado, v, "ok", f"As {len(tabelas)} tabelas foram lidas por completo ({total} linhas).")
        _concluir(estado)
    except Exception as e:
        estado.update(status="erro", erro=_primeira_linha(e))
        estado["log"].append("ERRO inesperado: " + traceback.format_exc(limit=2))


# ============================================================================================= SQL SERVER
def _descartar(con):
    """Fecha a conexao sem deixar erro escapar (uma conexao morta por bugcheck nao fecha). Devolve None."""
    if con is None:
        return None
    for acao in (lambda: con.rollback(), lambda: con.close()):
        try:
            acao()
        except Exception:
            pass
    return None


def _sql_literal(texto: str) -> str:
    return "N'" + texto.replace("'", "''") + "'"


def _conectar_sql(c, banco: str | None = None):
    """Conexao propria para validar: autocommit (RESTORE e DBCC nao rodam em transacao)."""
    import pyodbc
    from dataclasses import replace
    from app import sqlserver_conexao as sq
    alvo = replace(c, banco=banco) if banco is not None else c
    con = pyodbc.connect(sq.string_conexao(alvo), timeout=15, autocommit=True)
    return con


def _mensagens(cur) -> list[str]:
    msgs = []
    for _, texto in (getattr(cur, "messages", None) or []):
        t = str(texto)
        if "]" in t:
            t = t.rsplit("]", 1)[-1]
        msgs.append(t.strip())
    return [m for m in msgs if m]


def validar_sqlserver_banco(c, estado: dict) -> None:
    """c: sqlserver_conexao.ConexaoSqlServer (c.banco = banco do SysPDV)."""
    from app import sqlserver_conexao as sq
    try:
        v = _verificacao(estado, "Conexão e estado do banco")
        try:
            con = _conectar_sql(c, "master")
        except Exception as e:
            _fim(estado, v, "erro", "Não foi possível conectar no SQL Server: " + sq.mensagem_amigavel(e))
            _concluir(estado)
            return
        cur = con.cursor()
        cur.execute("SELECT name, state_desc, recovery_model_desc, page_verify_option_desc, compatibility_level, "
                    "user_access_desc FROM sys.databases WHERE name = ?", c.banco)
        linha = cur.fetchone()
        if not linha:
            _fim(estado, v, "erro", f"O banco '{c.banco}' não existe neste SQL Server.")
            _concluir(estado)
            return
        nome, estado_bd, recovery, verify, compat, acesso = linha
        itens = [f"Estado: {estado_bd}", f"Modelo de recuperação: {recovery}",
                 f"Verificação de página: {verify}", f"Nível de compatibilidade: {compat}", f"Acesso: {acesso}"]
        if estado_bd != "ONLINE":
            _fim(estado, v, "erro", f"O banco está {estado_bd} (o normal é ONLINE): SUSPECT/RECOVERY_PENDING indicam "
                 "banco danificado.", itens)
        elif verify != "CHECKSUM":
            _fim(estado, v, "aviso", f"Banco ONLINE, mas a verificação de página é {verify} (o recomendado é CHECKSUM: "
                 "detecta corrupção mais cedo).", itens)
        else:
            _fim(estado, v, "ok", "Banco ONLINE.", itens)

        v = _verificacao(estado, "DBCC CHECKDB (verificação oficial do SQL Server)")
        try:
            erros = _checkdb(cur, c.banco)
            if erros:
                _fim(estado, v, "erro", f"O CHECKDB encontrou {len(erros)} erro(s) de consistência. Não migre antes de "
                     "corrigir (restaurar um backup bom ou DBCC CHECKDB com REPAIR, com o banco em backup).", erros[:100])
            else:
                _fim(estado, v, "ok", "O CHECKDB não encontrou erros de alocação nem de consistência.")
        except Exception as e:
            texto = str(e)
            if "permission" in texto.lower() or "2571" in texto:
                _fim(estado, v, "aviso", "O usuário não tem permissão para rodar o DBCC CHECKDB (precisa ser sysadmin "
                     f"ou db_owner). ({_primeira_linha(e)})")
            else:
                _fim(estado, v, "erro", f"O CHECKDB falhou: {_primeira_linha(e)}")

        v = _verificacao(estado, "Páginas suspeitas registradas pelo SQL Server")
        try:
            cur.execute("SELECT file_id, page_id, event_type, error_count, last_update_date FROM msdb.dbo.suspect_pages "
                        "WHERE database_id = DB_ID(?)", c.banco)
            pags = [f"arquivo {r[0]}, página {r[1]}, evento {r[2]}, {r[3]} erro(s), {r[4]}" for r in cur.fetchall()]
            if pags:
                _fim(estado, v, "erro", f"O SQL Server já registrou {len(pags)} página(s) suspeita(s) neste banco.", pags)
            else:
                _fim(estado, v, "ok", "Nenhuma página suspeita registrada.")
        except Exception as e:
            _fim(estado, v, "aviso", f"Não foi possível ler msdb.dbo.suspect_pages: {_primeira_linha(e)}")
        con.close()
        _concluir(estado)
    except Exception as e:
        estado.update(status="erro", erro=_primeira_linha(e))
        estado["log"].append("ERRO inesperado: " + traceback.format_exc(limit=2))


def validar_sqlserver_bak(c, caminho_bak: str, estado: dict) -> None:
    """Valida um arquivo .bak. O caminho e do SERVIDOR SQL Server (e ele quem le o arquivo)."""
    from app import sqlserver_conexao as sq
    try:
        v = _verificacao(estado, "Conexão no SQL Server")
        try:
            con = _conectar_sql(c, "master")
        except Exception as e:
            _fim(estado, v, "erro", "Não foi possível conectar no SQL Server: " + sq.mensagem_amigavel(e))
            _concluir(estado, "Backup")
            return
        cur = con.cursor()
        cur.execute("SELECT @@VERSION")
        _fim(estado, v, "ok", "Conectado.", [(cur.fetchone()[0] or "").splitlines()[0]])
        disco = _sql_literal(caminho_bak)

        v = _verificacao(estado, "Cabeçalho do backup (RESTORE HEADERONLY)")
        com_checksum = False
        try:
            cur.execute(f"RESTORE HEADERONLY FROM DISK = {disco}")
            cols = [d[0].lower() for d in cur.description]
            conjuntos = [dict(zip(cols, r)) for r in cur.fetchall()]
            itens = []
            for b in conjuntos:
                tipo = {1: "completo", 2: "log", 5: "diferencial"}.get(b.get("backuptype"), b.get("backuptype"))
                itens.append(f"Conjunto {b.get('position')}: banco {b.get('databasename')}, backup {tipo}, "
                             f"de {b.get('backupfinishdate')}, servidor {b.get('servername')}, "
                             f"{round((b.get('backupsize') or 0) / 1048576, 1)} MB"
                             + (", com CHECKSUM" if b.get("haschecksums") else ", sem CHECKSUM")
                             + (", DANIFICADO" if b.get("isdamaged") else ""))
            com_checksum = any(b.get("haschecksums") for b in conjuntos)
            danificado = any(b.get("isdamaged") for b in conjuntos)
            if danificado:
                _fim(estado, v, "erro", "O cabeçalho marca o backup como DANIFICADO.", itens)
            else:
                _fim(estado, v, "ok", f"{len(conjuntos)} conjunto(s) de backup no arquivo.", itens)
        except Exception as e:
            _fim(estado, v, "erro", "O SQL Server não conseguiu ler o arquivo (caminho errado, sem permissão do "
                 f"serviço do SQL Server na pasta, ou não é um backup): {_primeira_linha(e)}")
            con.close()
            _concluir(estado, "Backup")
            return

        v = _verificacao(estado, "Arquivos do banco dentro do backup (RESTORE FILELISTONLY)")
        try:
            cur.execute(f"RESTORE FILELISTONLY FROM DISK = {disco}")
            cols = [d[0].lower() for d in cur.description]
            arqs = [dict(zip(cols, r)) for r in cur.fetchall()]
            _fim(estado, v, "ok", f"{len(arqs)} arquivo(s).",
                 [f"{a.get('logicalname')} ({a.get('type')}): {a.get('physicalname')}, "
                  f"{round((a.get('size') or 0) / 1048576, 1)} MB" for a in arqs])
        except Exception as e:
            _fim(estado, v, "aviso", f"Não foi possível listar os arquivos: {_primeira_linha(e)}")

        v = _verificacao(estado, "Verificação do backup (RESTORE VERIFYONLY)")
        try:
            opc = " WITH CHECKSUM" if com_checksum else ""
            cur.execute(f"RESTORE VERIFYONLY FROM DISK = {disco}{opc}")
            while cur.nextset():
                pass
            msgs = _mensagens(cur)
            if com_checksum:
                _fim(estado, v, "ok", "O backup é válido e as somas de verificação (CHECKSUM) conferem.", msgs)
            else:
                _fim(estado, v, "aviso", "O backup é legível e completo, mas foi feito SEM CHECKSUM: a verificação não "
                     "consegue garantir que os dados das páginas estão íntegros. Para ter certeza, restaure num banco "
                     "de teste e valide pelo modo Banco (DBCC CHECKDB).", msgs)
        except Exception as e:
            _fim(estado, v, "erro", f"O backup NÃO é válido: {_primeira_linha(e)}")
        con.close()
        _concluir(estado, "Backup")
    except Exception as e:
        estado.update(status="erro", erro=_primeira_linha(e))
        estado["log"].append("ERRO inesperado: " + traceback.format_exc(limit=2))


def _checkdb(cur, banco: str):
    """DBCC CHECKDB com TABLERESULTS: devolve a lista de erros (vazia = sem erro)."""
    cur.execute(f"DBCC CHECKDB ([{banco.replace(']', ']]')}]) WITH NO_INFOMSGS, ALL_ERRORMSGS, TABLERESULTS")
    erros = []
    while True:
        if cur.description:
            cols = [d[0].lower() for d in cur.description]
            for r in cur.fetchall():
                d = dict(zip(cols, r))
                erros.append(f"Erro {d.get('error')}, objeto {d.get('objectname') or d.get('objectid') or '-'}: "
                             f"{str(d.get('messagetext') or '')[:300]}")
        if not cur.nextset():
            break
    return erros


def validar_sqlserver_mdf(c, mdf: str, ldf: str, estado: dict) -> None:
    """Valida os arquivos fisicos (.MDF/.LDF): anexa como banco temporario, CHECKDB, desanexa."""
    from app import sqlserver_conexao as sq
    try:
        v = _verificacao(estado, "Conexão no SQL Server")
        try:
            con = _conectar_sql(c, "master")
        except Exception as e:
            _fim(estado, v, "erro", "Não foi possível conectar no SQL Server: " + sq.mensagem_amigavel(e))
            _concluir(estado, "Banco")
            return
        cur = con.cursor()
        cur.execute("SELECT CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50)), @@VERSION")
        produto, versao_txt = cur.fetchone()
        _fim(estado, v, "ok", "Conectado.", [(versao_txt or "").splitlines()[0]])

        v = _verificacao(estado, "Cabeçalho do arquivo .MDF (sem anexar)")
        try:
            cur.execute(f"DBCC CHECKPRIMARYFILE ({_sql_literal(mdf)}, 2)")
            info = {str(r[0]).strip().lower(): r[1] for r in cur.fetchall()}
            while cur.nextset():
                pass
            nome = info.get("database name") or info.get("databasename")
            versao_mdf = info.get("database version") or info.get("version")
            itens = [f"Banco: {nome}", f"Versão interna do arquivo: {versao_mdf}",
                     f"Collation: {info.get('collation')}" if info.get("collation") else None]
            try:
                cur.execute("SELECT CAST(DATABASEPROPERTYEX('master', 'Version') AS int)")
                versao_servidor = cur.fetchone()[0]
            except Exception:
                versao_servidor = None
            if versao_servidor and versao_mdf and int(versao_mdf) < int(versao_servidor):
                itens.append(f"Versão interna deste SQL Server: {versao_servidor}")
                _fim(estado, v, "aviso", f"O arquivo é de um SQL Server mais antigo (versão {versao_mdf}): ao anexar, este "
                     f"SQL Server vai ATUALIZÁ-LO para a versão {versao_servidor} - por isso use uma cópia.",
                     [i for i in itens if i])
            else:
                _fim(estado, v, "ok", "O SQL Server leu o cabeçalho do arquivo.", [i for i in itens if i])
        except Exception as e:
            _fim(estado, v, "erro", "O SQL Server não conseguiu ler o .MDF (caminho errado, sem permissão do serviço do "
                 f"SQL Server na pasta, arquivo em uso por outro SQL Server, ou não é um MDF): {_primeira_linha(e)}")
            con.close()
            _concluir(estado, "Banco")
            return

        temporario = "MIGRADOR_VALIDACAO_" + time.strftime("%Y%m%d_%H%M%S")
        v = _verificacao(estado, f"Anexar como banco temporário ({temporario})")
        try:
            arquivos = f"(FILENAME = {_sql_literal(mdf)})" + (f", (FILENAME = {_sql_literal(ldf)})" if ldf else "")
            modo = "FOR ATTACH" if ldf else "FOR ATTACH_REBUILD_LOG"
            cur.execute(f"CREATE DATABASE [{temporario}] ON {arquivos} {modo}")
            while cur.nextset():
                pass
            msgs = _mensagens(cur)
            aviso = [m for m in msgs if "upgrad" in m.lower() or "convert" in m.lower()]
            if aviso:
                _fim(estado, v, "aviso", "Anexado, mas o SQL Server ATUALIZOU a versão do arquivo (ele não abre mais "
                     "na versão antiga do SQL Server).", msgs[:20])
            elif not ldf:
                _fim(estado, v, "aviso", "Anexado sem o .LDF: o SQL Server recriou o arquivo de log.", msgs[:20])
            else:
                _fim(estado, v, "ok", "Arquivos anexados.", msgs[:20])
        except Exception as e:
            _fim(estado, v, "erro", f"O SQL Server não conseguiu anexar os arquivos: {_primeira_linha(e)}. Arquivo "
                 "corrompido, MDF e LDF que não são do mesmo banco, ou o LDF faltando com transações abertas.")
            con.close()
            _concluir(estado, "Banco")
            return

        try:
            v = _verificacao(estado, "DBCC CHECKDB (verificação oficial do SQL Server)")
            try:
                erros = _checkdb(cur, temporario)
                if erros:
                    _fim(estado, v, "erro", f"O CHECKDB encontrou {len(erros)} erro(s) de consistência nos arquivos.",
                         erros[:100])
                else:
                    _fim(estado, v, "ok", "O CHECKDB não encontrou erros de alocação nem de consistência.")
            except Exception as e:
                _fim(estado, v, "erro", f"O CHECKDB falhou: {_primeira_linha(e)}")
        finally:
            v = _verificacao(estado, "Desanexar o banco temporário")
            try:
                cur.execute(f"ALTER DATABASE [{temporario}] SET SINGLE_USER WITH ROLLBACK IMMEDIATE")
                cur.execute(f"EXEC master.dbo.sp_detach_db @dbname = N'{temporario}'")
                _fim(estado, v, "ok", "Banco temporário desanexado: os arquivos ficaram livres.")
            except Exception as e:
                _fim(estado, v, "aviso", f"Não consegui desanexar {temporario} (faça pelo SQL Server Management Studio): "
                     f"{_primeira_linha(e)}")
        con.close()
        _concluir(estado, "Banco")
    except Exception as e:
        estado.update(status="erro", erro=_primeira_linha(e))
        estado["log"].append("ERRO inesperado: " + traceback.format_exc(limit=2))


# ================================================================================ REPARO DO FIREBIRD
def _pasta_e_nome(caminho_servidor: str):
    """Caminho do banco NO SERVIDOR (pode ser Windows ou o de dentro do container)."""
    import ntpath
    import posixpath
    mod = ntpath if ("\\" in caminho_servidor or ":" in caminho_servidor[:3]) else posixpath
    pasta, arquivo = mod.split(caminho_servidor)
    return mod, pasta, mod.splitext(arquivo)[0]


def _arquivo_no_computador(c) -> str | None:
    """Caminho do .FDB NESTE computador (local ou, no Docker, dentro da pasta compartilhada), se acessivel."""
    import os
    if c.modo == "docker" and c.pasta_host and c.pasta_container:
        srv = c.caminho_servidor.replace("\\", "/")
        pc = c.pasta_container.replace("\\", "/").rstrip("/")
        if srv.startswith(pc + "/"):
            cand = os.path.join(c.pasta_host, *srv[len(pc) + 1:].split("/"))
            return cand if os.path.isfile(cand) else None
        return None
    return c.caminho if os.path.isfile(c.caminho) else None


def _contar_tabelas(c, tabelas, estado, rotulo) -> dict:
    """COUNT(*) de cada tabela, sobrevivendo ao "bugcheck" (reconecta). Tabela que nao conta = None."""
    from app.firebird_conexao import conectar_servidor
    contagens, con = {}, None
    for t in tabelas:
        try:
            if con is None:
                con = conectar_servidor(c)
            cur = con.cursor()
            cur.execute(f'SELECT COUNT(*) FROM "{t}"')
            contagens[t] = cur.fetchone()[0]
            cur.close()
        except Exception as e:
            contagens[t] = None
            estado["log"].append(f"  {rotulo} {t}: não foi possível contar ({_primeira_linha(e)[:120]})")
            con = _descartar(con)
    _descartar(con)
    return contagens


def reparar_firebird(c, opcoes: dict, estado: dict) -> None:
    """Repara um .FDB corrompido pelo servico do Firebird, SEM sobrescrever o original. Ordem segura:
      1. copia de trabalho do arquivo ANTES de ler qualquer dado do original (um "bugcheck" deixa paginas
         presas no servidor e a copia sairia inconsistente);
      2. mend na copia (gfix -mend -full -ignore) -> backup ignorando erros (gbak -b -g -ig) -> restore num
         ARQUIVO NOVO (gbak -c) - cada passo com a sua propria conexao de servico (um passo com erro deixa a
         conexao "busy");
      3. confere o reparado (validacao do servidor + contagem das tabelas);
      4. por ultimo conta o original e compara (se a contagem esbarrar na corrupcao, o reparo ja esta pronto).
    Sem acesso ao arquivo para copiar (Firebird em outro servidor), o mend roda no original - so com a
    confirmacao de que ha copia de seguranca. Os registros realmente destruidos se perdem; o resto volta."""
    import os
    import shutil
    import fdb
    from dataclasses import replace
    from app.firebird_conexao import conectar_servidor, mensagem_amigavel
    exclusivo = bool(opcoes.get("exclusivo"))
    em_shutdown = False
    trabalho_local = None
    original = None
    servico = lambda: fdb.services.connect(host=f"{c.host}/{c.porta}", user=c.usuario, password=c.senha)

    def fechar(svc):
        try:
            svc.close()
        except Exception:
            pass

    try:
        # ------------------------------------------------------------------ 1. conexao e copia de trabalho
        v = _verificacao(estado, "Conexão com o banco")
        original_bloqueado = False
        try:
            c, container, itens = _resolver_servidor(c, opcoes.get("modo") or "auto", opcoes.get("container"), estado, v)
        except ValueError as e:
            _fim(estado, v, "erro", str(e))
            raise _Parar()
        try:
            con = conectar_servidor(c)                    # so le a versao (nenhum dado de tabela)
            cur = con.cursor()
            cur.execute("SELECT RDB$GET_CONTEXT('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
            versao = cur.fetchone()[0]
            _descartar(con)
        except Exception as e:
            if "bugcheck" not in str(e).lower():
                _fim(estado, v, "erro", "Não foi possível abrir o banco: " + mensagem_amigavel(e))
                raise _Parar()
            # "can't attach after bugcheck": o servidor bloqueou o ORIGINAL depois de ler um registro corrompido
            # (ex.: na validacao). O reparo trabalha numa COPIA (outro arquivo), entao segue.
            original_bloqueado = True
            svc = fdb.services.connect(host=f"{c.host}/{c.porta}", user=c.usuario, password=c.senha)
            try:
                versao = svc.get_server_version()
            finally:
                fechar(svc)
        original = c.caminho_servidor
        banco = original
        mod, pasta, nome = _pasta_e_nome(original)
        carimbo = time.strftime("%Y%m%d_%H%M%S")
        fbk = mod.join(pasta, f"{nome}_REPARO_{carimbo}.FBK")
        novo = mod.join(pasta, f"{nome}_REPARADO_{carimbo}.FDB")
        if original_bloqueado:
            _fim(estado, v, "aviso", f"Firebird {versao}. O servidor está BLOQUEANDO o original (\"can't attach after "
                 "bugcheck\": acontece depois de ler um registro corrompido, ex. na validação). O reparo segue pela cópia "
                 "de trabalho; para o original voltar a abrir, reinicie o servidor Firebird (ou o container).",
                 itens + [f"Original: {original}", f"Backup intermediário: {fbk}", f"Banco reparado (novo): {novo}"])
        else:
            _fim(estado, v, "ok", f"Firebird {versao}. O original não é substituído: o reparado vai para um arquivo novo.",
                 itens + [f"Original: {original}", f"Backup intermediário: {fbk}", f"Banco reparado (novo): {novo}"])

        v = _verificacao(estado, "Cópia de trabalho (o reparo não mexe no original)")
        local = _arquivo_no_computador(c)
        if local:
            trabalho_local = os.path.join(os.path.dirname(local), f"{nome}_TRABALHO_{carimbo}.FDB")
            try:
                shutil.copyfile(local, trabalho_local)
                os.chmod(trabalho_local, 0o666)           # o servidor Firebird (outro usuario) precisa gravar
                banco = mod.join(pasta, os.path.basename(trabalho_local))
                _fim(estado, v, "ok", "Cópia de trabalho criada: o reparo (mend) altera só ela e ela é apagada no fim. "
                     "Os dados do original não são alterados.", [f"Cópia de trabalho: {banco}"])
            except Exception as e:
                trabalho_local = None
                _fim(estado, v, "aviso", f"Não consegui copiar o arquivo ({_primeira_linha(e)}).")
        if not trabalho_local and original_bloqueado:
            _fim(estado, v, "erro", "Sem acesso ao arquivo para fazer a cópia de trabalho e o servidor está bloqueando o "
                 "original (\"can't attach after bugcheck\"): reinicie o servidor Firebird (ou o container) e repare de novo.")
            raise _Parar()
        if not trabalho_local:
            if not opcoes.get("confirmo_copia"):
                _fim(estado, v, "erro", "O migrador não acessa o arquivo neste computador para fazer a cópia de trabalho "
                     "(ex.: Firebird em outro servidor). O reparo teria de marcar os registros corrompidos NO ORIGINAL: "
                     "faça uma cópia de segurança do .FDB, marque \"Tenho cópia de segurança\" e repare de novo.")
                raise _Parar()
            if v["status"] == "rodando":
                _fim(estado, v, "aviso", "Sem cópia de trabalho: o reparo vai marcar os registros corrompidos no ORIGINAL "
                     "(você confirmou ter uma cópia de segurança).")
            if exclusivo:
                v = _verificacao(estado, "Uso exclusivo do banco (desconecta os outros usuários)")
                svc = servico()
                try:
                    svc.shutdown(original, fdb.services.SHUT_SINGLE, fdb.services.SHUT_FORCE, 0)
                    em_shutdown = True
                    _fim(estado, v, "ok", "Banco em uso exclusivo (modo single): os outros usuários foram desconectados.")
                except Exception as e:
                    _fim(estado, v, "erro", f"Não foi possível colocar o banco em uso exclusivo: {_primeira_linha(e)}")
                    raise _Parar()
                finally:
                    fechar(svc)

        # ------------------------------------------------------------------ 2. mend -> backup -> restore
        v = _verificacao(estado, "Marcar os registros corrompidos (gfix -mend -full -ignore)")
        svc = servico()
        try:
            # = gfix -mend -full -ignore (o "validar" padrao da biblioteca nao combina com o mend)
            svc.repair(banco, mend_database=1, ignore_checksums=1, validate_database=0, validate_record_fragments=1)
            saida = [l for l in svc.readlines() if l and l.strip()]
            _fim(estado, v, "ok", "Registros e fragmentos corrompidos marcados para descarte (ficam fora do banco novo).",
                 saida[:30])
        except Exception as e:
            texto = str(e).lower()
            if "secondary server attachments" in texto or "in use" in texto or "lock" in texto:
                _fim(estado, v, "erro", "O banco está aberto por outras conexões: o Firebird só repara com o banco só para "
                     "ele. Feche o SysPDV/IBExpert/migrações (ou marque \"Forçar uso exclusivo\") e repare de novo.")
                raise _Parar()
            # o mend pode reclamar e mesmo assim o backup conseguir ler: quem decide e o backup
            _fim(estado, v, "aviso", f"O mend terminou com aviso: {_primeira_linha(e)}. Seguindo para o backup.")
        finally:
            fechar(svc)

        v = _verificacao(estado, "Backup ignorando os erros (gbak -b -g -ig)")
        linhas = []
        svc = servico()
        try:
            svc.backup(banco, fbk, ignore_checksums=1, ignore_limbo_transactions=1, collect_garbage=0, callback=linhas.append)
            erros = [l for l in linhas if "ERROR" in l.upper()]
            if erros:
                raise RuntimeError(" | ".join(erros[:3]))
            _fim(estado, v, "ok", f"Backup feito: {fbk}")
        except Exception as e:
            _fim(estado, v, "erro", f"O backup não conseguiu ler o banco mesmo ignorando os erros: {_primeira_linha(e)}. "
                 "A corrupção é grave demais para o reparo automático: procure um backup anterior (.FBK/.GBK) ou "
                 "um serviço especializado em recuperação de Firebird.", linhas[-10:])
            raise _Parar()
        finally:
            fechar(svc)

        v = _verificacao(estado, "Restaurar em um banco novo (gbak -c)")
        linhas = []
        svc = servico()
        try:
            svc.restore(fbk, novo, replace=0, commit_after_each_table=1, callback=linhas.append)
            erros = [l for l in linhas if "ERROR" in l.upper()]
            if erros:
                raise RuntimeError(" | ".join(erros[:3]))
            _fim(estado, v, "ok", f"Banco novo criado: {novo}")
        except Exception as e:
            _fim(estado, v, "erro", f"A restauração falhou: {_primeira_linha(e)}", linhas[-10:])
            raise _Parar()
        finally:
            fechar(svc)

        # ------------------------------------------------------------------ 3. confere o reparado
        v = _verificacao(estado, "Validar o banco reparado")
        svc = servico()
        try:
            svc.repair(novo, read_only_validation=1)
            svc.readlines()
            validado = True
        except Exception as e:
            validado = False
            _fim(estado, v, "erro", f"O banco reparado ainda apresentou erro na validação do servidor: {_primeira_linha(e)}")
        finally:
            fechar(svc)
        c_novo = replace(c, caminho=novo, modo="local")
        con = conectar_servidor(c_novo)
        cur = con.cursor()
        cur.execute("SELECT TRIM(RDB$RELATION_NAME) FROM RDB$RELATIONS WHERE COALESCE(RDB$SYSTEM_FLAG, 0) = 0 "
                    "AND RDB$VIEW_BLR IS NULL AND RDB$EXTERNAL_FILE IS NULL ORDER BY 1")
        tabelas = [r[0] for r in cur.fetchall()]
        _descartar(con)
        contagem_nova = _contar_tabelas(c_novo, tabelas, estado, "reparado")
        if validado:
            _fim(estado, v, "ok", f"O banco reparado passou na validação do servidor e as {len(tabelas)} tabelas abrem "
                 f"({sum(n or 0 for n in contagem_nova.values())} registros).")

        # ------------------------------------------------------------------ 4. compara com o original
        v = _verificacao(estado, "Comparar com o original (registros por tabela)")
        contagem_original = ({} if original_bloqueado else _contar_tabelas(c, tabelas, estado, "original"))
        linhas_tab = []
        for t in tabelas:
            n, antes = contagem_nova.get(t), contagem_original.get(t)
            if antes is None:
                st, msg = "aviso", "o original não pôde ser contado (tabela corrompida): confira com o SysPDV"
            elif (n or 0) < antes:
                st, msg = "erro", f"{antes - (n or 0)} registro(s) a menos que o original"
            else:
                st, msg = "ok", ""
            linhas_tab.append({"nome": t, "status": st, "linhas": n or 0, "original": antes, "mensagem": msg})
        estado["tabelas"] = linhas_tab
        perdas = [x for x in linhas_tab if x["status"] == "erro"]
        duvidas = [x for x in linhas_tab if x["status"] == "aviso"]
        if original_bloqueado:
            for x in linhas_tab:
                x["status"], x["mensagem"] = "aviso", "o original está bloqueado pelo servidor: compare com o SysPDV"
            _fim(estado, v, "aviso", "Não deu para contar o original: o servidor está bloqueando o banco depois do erro "
                 "grave. Reinicie o servidor Firebird/container e valide o original e o reparado aqui, ou confira as "
                 "quantidades no SysPDV.")
        elif perdas or duvidas:
            partes = []
            if perdas:
                partes.append(f"{len(perdas)} tabela(s) com menos registros que o original: "
                              + ", ".join(f"{x['nome']} (-{x['original'] - x['linhas']})" for x in perdas[:10]))
            if duvidas:
                partes.append(f"{len(duvidas)} tabela(s) que não puderam ser contadas no original (eram as corrompidas): "
                              + ", ".join(f"{x['nome']} ({x['linhas']} no reparado)" for x in duvidas[:10]))
            _fim(estado, v, "aviso", "; ".join(partes) + ". Os registros que estavam corrompidos foram descartados: "
                 "confira essas tabelas no SysPDV antes de migrar.")
        else:
            _fim(estado, v, "ok", "Nenhuma tabela perdeu registros em relação ao original.")

        v = _verificacao(estado, "Próximo passo")
        _fim(estado, v, "ok", "Confira o banco reparado (valide-o aqui e abra no SysPDV/IBExpert). Se estiver certo, com o "
             "SysPDV fechado, renomeie o original (guarde-o) e dê ao reparado o nome do original — ou use o reparado "
             "direto como origem em Conexões.",
             [f"Reparado: {novo}",
              f"Original (dados não alterados): {original}" if trabalho_local
              else f"Original (registros corrompidos marcados pelo mend): {original}",
              f"Backup do reparo: {fbk}"])
        _concluir(estado, "Reparo")
    except _Parar:
        _concluir(estado, "Reparo")
    except Exception as e:
        estado.update(status="erro", erro=_primeira_linha(e))
        estado["log"].append("ERRO inesperado: " + traceback.format_exc(limit=2))
    finally:
        if trabalho_local:
            try:
                os.remove(trabalho_local)
                estado["log"].append("Cópia de trabalho apagada.")
            except Exception:
                pass
        if em_shutdown and original:
            svc = None
            try:
                svc = servico()
                svc.bring_online(original, fdb.services.SHUT_NORMAL)
                estado["log"].append("Banco original liberado (online) de novo.")
            except Exception as e:
                estado["log"].append(f"ATENÇÃO: não consegui liberar o banco original (gfix -online): {_primeira_linha(e)}")
            finally:
                if svc is not None:
                    fechar(svc)


class _Parar(Exception):
    pass
