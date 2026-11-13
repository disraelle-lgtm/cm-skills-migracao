"""
Motor do migrador: cada pasta em comandos/ e um MODULO (uma entidade).

  comandos/01_secao/
    modulo.json      nome, grupo e chave (o que aparece na tela)
    origem.sql       SELECT no SysPDV (Firebird)            - obrigatorio
    transformar.py   ajusta cada linha em Python            - opcional
    validar.sql      precisa devolver 1 linha, senao erro   - opcional
    existe.sql       procura o registro no VarejoFacil      - opcional
    inserir.sql      INSERT no VarejoFacil (PostgreSQL)     - obrigatorio
    atualizar.sql    UPDATE quando ja existe e mudou        - opcional
    antes.sql        roda 1 vez antes do modulo (Postgres)  - opcional
    depois.sql       roda 1 vez depois do modulo (Postgres) - opcional
    finalizar.sql    roda SEMPRE no fim da execucao, mesmo se der erro no meio
                     (ex.: religar triggers desligadas) - opcional

Item SO DE SQL: uma pasta com apenas antes.sql e/ou depois.sql (sem origem.sql)
roda esses comandos uma vez. Ex.: comandos/11_ajustes_pessoas/.

OPCOES de um item (ex.: "Incluir produtos fora de linha"): declaradas no modulo.json
  "opcoes": [{"id": "fora_de_linha", "rotulo": "Incluir produtos fora de linha", "padrao": true}]
viram um checkbox ao lado do item na tela e podem ser usadas no origem.sql como
:opcao_fora_de_linha (vale 1 marcado / 0 desmarcado) e nos .sql do Postgres como
%(opcao_fora_de_linha)s. As opcoes valem para todos os itens da execucao (ex.: Preco e
EAN usam a mesma opcao do Produto).

CONTAGEM NA ORIGEM: antes de cada etapa o motor conta os registros da tabela de origem
(a primeira tabela do FROM do origem.sql, ou "tabela_origem" / "contagem_origem" do
modulo.json) e mostra na tela ao lado do que foi migrado.

No transformar.py, uma chave "_aviso" no dicionario vira mensagem no relatorio
(ex.: "cliente sem CPF/CNPJ") e nao vai para o banco.

Para cada linha do origem.sql:
  1. transformar.py (se existir) devolve o dicionario com os valores finais;
  2. validar.sql (se existir) precisa encontrar algo - ex.: a secao do grupo;
  3. existe.sql (se existir) busca o registro atual:
       - nao achou            -> inserir.sql                    (inserido)
       - achou e algo mudou   -> atualizar.sql                  (atualizado)
       - achou e tudo igual   -> nada                           (sem_alteracao)
     "mudou" = alguma coluna devolvida pelo existe.sql com o mesmo nome de um
     campo do dicionario tem valor diferente.

Um item tambem pode ter ETAPAS: em vez dos arquivos acima, a pasta do item tem
subpastas (01_aplicacao/, 02_marca/...), cada uma com os seus arquivos. O item vira
um checkbox so e as etapas rodam em ordem. Ex.: comandos/04_tabelas_basicas/.

Nos .sql do PostgreSQL, os valores entram como %(nome_do_campo)s.
Cada linha roda num savepoint: erro numa linha nao derruba as outras.
Modulos rodam na ordem do nome da pasta (01_, 02_, ...). Pastas que comecam
com "_" (ex.: _modelo) sao ignoradas.
"""
from __future__ import annotations

import csv
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
import json
import time
import traceback
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from .ajudantes import Pular

RAIZ = Path(__file__).resolve().parent.parent
PASTA_COMANDOS = RAIZ / "comandos"
# Abas da tela "2. Dados a serem migrados": cada uma tem a sua pasta de comandos (mesma estrutura)
CONJUNTOS = {"inicial": PASTA_COMANDOS, "virada": RAIZ / "comandos_virada"}


def descobrir_conjunto(conjunto: str) -> list["Modulo"]:
    """Inicial: comandos/. Virada: os MESMOS itens de comandos/ + os itens so da virada
    (comandos_virada/, ex.: EAN e SPED dos codigos trocados), na ordem das pastas."""
    if conjunto == "inicial":
        return descobrir(PASTA_COMANDOS)
    if conjunto == "virada":
        return sorted(descobrir(PASTA_COMANDOS) + descobrir(CONJUNTOS["virada"]), key=lambda m: m.id)
    raise ValueError(f"Conjunto de comandos desconhecido: {conjunto}")


def pasta_do_conjunto(conjunto: str) -> Path:
    if conjunto not in CONJUNTOS:
        raise ValueError(f"Conjunto de comandos desconhecido: {conjunto}")
    return CONJUNTOS[conjunto]
PASTA_RELATORIOS = RAIZ / "reports"

ARQUIVOS = ["modulo.json", "origem.sql", "origem.sqlserver.sql", "transformar.py", "validar.sql", "existe.sql",
            "inserir.sql", "atualizar.sql", "antes.sql", "depois.sql", "finalizar.sql", "nao_lidos.sql"]
OBRIGATORIOS = ["origem.sql", "inserir.sql"]


class ErroValidacao(Exception):
    pass


@dataclass
class Etapa:
    """Uma pasta com comandos (origem.sql, inserir.sql...)."""
    id: str
    pasta: Path
    nome: str
    chave: list[str] = field(default_factory=list)
    mensagem_validacao: str = "validar.sql nao encontrou o registro pai"
    problemas: list[str] = field(default_factory=list)
    tabela_origem: str | None = None      # para a contagem na origem (padrao: 1a tabela do FROM)
    contagem_origem: str | None = None    # ou um SELECT COUNT(...) proprio
    # Migracao VIRADA: campos que sao codigo de cliente/produto ({"procod": "produto"}) e, no item
    # principal, o campo que ganha codigo novo ({"campo": "procod", "tipo": "produto", "balanca": "proenvbal"})
    depara: dict = field(default_factory=dict)
    depara_gera: dict = field(default_factory=dict)
    # se a consulta de origem falhar (ex.: SysPDV de versao antiga, sem a coluna), registra um aviso e
    # segue a migracao em vez de parar
    ignorar_se_origem_falhar: bool = False
    # sem "Na origem"/"Nao migrados" (etapa que so confere uma parte dos registros, ex.: zerar saldo ja lancado)
    sem_contagem_origem: bool = False
    # validar.sql sem resultado = registro PULADO (nao e erro): ex. produto sem saldo lancado para zerar
    validar_pula: bool = False
    exige_produto: list[str] = field(default_factory=list)   # campos com codigo de produto que precisa existir no VarejoFacil

    def sql(self, nome: str) -> str | None:
        """Conteudo do .sql SEM as linhas de comentario (--). Arquivo ausente ou so com
        comentarios = None (o passo e pulado). Tirar os comentarios evita que um %
        escrito num comentario seja confundido com um %(campo)s."""
        p = self.pasta / nome
        if not p.exists():
            return None
        linhas = [l for l in p.read_text(encoding="utf-8").splitlines() if not l.strip().startswith("--")]
        texto = "\n".join(linhas).strip().rstrip(";").strip()
        return texto or None

    def arquivos(self) -> list[str]:
        return [a for a in ARQUIVOS if (self.pasta / a).exists()]

    def carregar_transformar(self):
        """Recarrega o transformar.py a cada execucao: editou, ja vale."""
        p = self.pasta / "transformar.py"
        if not p.exists():
            return None
        # compila direto do texto: sem cache (__pycache__) dentro da pasta de comandos
        espaco = {"__name__": f"comandos_{self.id.replace('/', '_')}_transformar", "__file__": str(p)}
        exec(compile(p.read_text(encoding="utf-8"), str(p), "exec"), espaco)
        if not callable(espaco.get("transformar")):
            raise RuntimeError(f"{p} precisa ter uma funcao transformar(linha)")
        return espaco["transformar"]


@dataclass
class Modulo:
    """Um checkbox da tela: uma etapa (pasta com comandos) ou varias (subpastas)."""
    id: str
    pasta: Path
    nome: str
    grupo: str = "Outros"
    descricao: str = ""
    etapas: list[Etapa] = field(default_factory=list)
    problemas: list[str] = field(default_factory=list)
    # "automatico_com_grupo" no modulo.json: o item nao vira checkbox e roda sozinho, no fim,
    # quando algum item desse grupo for marcado (ex.: Ajustes finais de Pessoas).
    automatico_com_grupo: str | None = None
    automatico_sempre: bool = False      # sem checkbox: entra em TODA execucao (ex.: fila do Panama no fim)
    automatico_com_itens: list = field(default_factory=list)   # sem checkbox: entra se algum desses itens for marcado
    opcoes: list[dict] = field(default_factory=list)   # checkboxes extras ao lado do item

    def para_dict(self) -> dict:
        return {"id": self.id, "nome": self.nome, "grupo": self.grupo, "descricao": self.descricao,
                "pasta": str(self.pasta.relative_to(RAIZ)),
                "etapas": [{"id": e.id, "nome": e.nome, "arquivos": e.arquivos()} for e in self.etapas],
                "arquivos": self.etapas[0].arquivos() if len(self.etapas) == 1 else [],
                "problemas": self.problemas + [f"{e.nome}: {p}" for e in self.etapas for p in e.problemas],
                "automatico_com_grupo": self.automatico_com_grupo, "automatico_sempre": self.automatico_sempre,
                "automatico_com_itens": self.automatico_com_itens,
                "opcoes": self.opcoes}


def _ler_meta(pasta: Path) -> dict:
    if not (pasta / "modulo.json").exists():
        return {}
    try:
        return json.loads((pasta / "modulo.json").read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        return {"problema": f"modulo.json invalido: {e}"}


def _etapa(pasta: Path, id_: str) -> Etapa:
    meta = _ler_meta(pasta)
    e = Etapa(id=id_, pasta=pasta, nome=meta.get("nome", pasta.name), chave=meta.get("chave", []),
              mensagem_validacao=meta.get("mensagem_validacao", Etapa.mensagem_validacao),
              tabela_origem=meta.get("tabela_origem"), contagem_origem=meta.get("contagem_origem"),
              depara=meta.get("depara", {}), depara_gera=meta.get("depara_gera", {}),
              ignorar_se_origem_falhar=bool(meta.get("ignorar_se_origem_falhar", False)),
              sem_contagem_origem=bool(meta.get("sem_contagem_origem", False)),
              validar_pula=bool(meta.get("validar_pula", False)),
              exige_produto=list(meta.get("exige_produto") or []))
    if "problema" in meta:
        e.problemas.append(meta["problema"])
    if not _so_sql(pasta):
        e.problemas += [f"falta {a}" for a in OBRIGATORIOS if not (pasta / a).exists()]
    return e


def _so_sql(pasta: Path) -> bool:
    """Pasta sem origem.sql, mas com antes.sql e/ou depois.sql: roda so esses comandos."""
    return (not (pasta / "origem.sql").exists()
            and any((pasta / a).exists() for a in ("antes.sql", "depois.sql", "finalizar.sql")))


def _visiveis(pasta: Path) -> list[Path]:
    return [p for p in sorted(pasta.iterdir()) if p.is_dir() and not p.name.startswith(("_", ".", "__"))]


def com_automaticos(escolhidos: list[Modulo], todos: list[Modulo]) -> list[Modulo]:
    """Acrescenta os itens automaticos cujo grupo tem algum item escolhido; ordem das pastas."""
    grupos = {m.grupo for m in escolhidos}
    ids = {m.id for m in escolhidos}
    extras = [m for m in todos if (m.automatico_com_grupo in grupos or m.automatico_sempre
                                   or ids.intersection(m.automatico_com_itens)) and m not in escolhidos]
    return sorted(escolhidos + extras, key=lambda m: m.id)


def descobrir(pasta: Path = PASTA_COMANDOS) -> list[Modulo]:
    modulos = []
    for p in _visiveis(pasta) if pasta.exists() else []:
        meta = _ler_meta(p)
        m = Modulo(id=p.name, pasta=p, nome=meta.get("nome", p.name), grupo=meta.get("grupo", "Outros"),
                   descricao=meta.get("descricao", ""),
                   automatico_com_grupo=meta.get("automatico_com_grupo"),
                   automatico_sempre=bool(meta.get("automatico_sempre", False)),
                   automatico_com_itens=list(meta.get("automatico_com_itens", [])),
                   opcoes=meta.get("opcoes", []))
        if (p / "origem.sql").exists() or _so_sql(p):        # item simples (ou so de SQL)
            m.etapas = [_etapa(p, p.name)]
            m.etapas[0].nome = m.nome
        else:                                                # item com etapas (subpastas)
            m.etapas = [_etapa(sub, f"{p.name}/{sub.name}") for sub in _visiveis(p)]
            if not m.etapas:
                m.problemas.append("sem origem.sql e sem subpastas de etapas")
            if "problema" in meta:
                m.problemas.append(meta["problema"])
        modulos.append(m)
    return modulos


# ------------------------------------------------------------- execucao ---
def formatar_duracao(segundos: float | None) -> str:
    """0,8s / 45s / 2min 05s / 1h 02min 05s"""
    if segundos is None:
        return "-"
    if segundos < 10:
        return f"{segundos:.1f}s".replace(".", ",")
    s = int(round(segundos))
    h, resto = divmod(s, 3600)
    m, s = divmod(resto, 60)
    if h:
        return f"{h}h {m:02d}min {s:02d}s"
    if m:
        return f"{m}min {s:02d}s"
    return f"{s}s"


def _vazio(nome: str) -> dict:
    return {"nome": nome, "status": "aguardando", "total_origem": None, "inicio_ts": None, "duracao": None, "lidos": 0, "inseridos": 0, "atualizados": 0,
            "sem_alteracao": 0, "pulados": 0, "erros": 0, "relatorio_erros": None, "amostra_pulados": [], "amostra_avisos": [], "avisos": 0, "nao_lidos_total": 0, "nao_lidos": [], "relatorio_nao_lidos": None, "amostra_erros": [], "relatorio": None, "mensagem": None}


def valores_opcoes(modulos: list[Modulo], escolhidas: dict | None) -> dict[str, bool]:
    """Padrao de cada opcao declarada nos modulos, sobreposto pelo que veio da tela."""
    valores = {o["id"]: bool(o.get("padrao", False)) for m in modulos for o in m.opcoes}
    for k, v in (escolhidas or {}).items():
        valores[k] = v if k.endswith("_data") else bool(v)      # opcao de data (ex.: movimentacao_data) guarda o valor
    return valores


def executar(modulos: list[Modulo], con_fb, con_pg, simular: bool, estado: dict,
             opcoes: dict[str, bool] | None = None, dialeto: str = "firebird", depara=None) -> None:
    """Roda os itens e suas etapas em ordem. Real: commit ao fim de cada etapa.
    Simulacao: tudo numa transacao so, desfeita no final (as etapas seguintes enxergam
    o que as anteriores 'gravariam', ex.: o grupo ve as secoes novas)."""
    log = estado["log"].append
    pasta_exec = PASTA_RELATORIOS / estado["id"]
    pasta_exec.mkdir(parents=True, exist_ok=True)
    fila = []
    for m in modulos:
        for e in m.etapas:
            nome = m.nome if len(m.etapas) == 1 else f"{m.nome} › {e.nome}"
            estado["modulos"][e.id] = _vazio(nome)
            # para a tela agrupar e recolher: grupo (ex.: Cadastro de Produto), item e etapa
            estado["modulos"][e.id].update(grupo=m.grupo, item_id=m.id, item=m.nome,
                                           etapa=e.nome if len(m.etapas) > 1 else None,
                                           automatico=bool(m.automatico_com_grupo or m.automatico_sempre))
            fila.append((m, e, nome))
    if depara is not None:                     # migracao VIRADA com arquivo(s) de codigos
        depara.preparar(con_pg, log)
    try:
        for m, e, nome in fila:
            r = estado["modulos"][e.id]
            problemas = m.problemas + e.problemas
            if problemas:
                r.update(status="erro", mensagem="; ".join(problemas))
                log(f"[{nome}] não executado: {r['mensagem']}")
                raise _Parar()
            r["status"] = "rodando"
            r["inicio_ts"] = time.time()
            relogio = time.monotonic()
            log(f"[{nome}] início ({e.pasta.relative_to(RAIZ)})")
            try:
                detalhes = _executar_modulo(e, con_fb, con_pg, r, log, nome, opcoes or {}, dialeto, depara)
            except Exception as erro:
                con_pg.rollback()
                r.update(status="erro", mensagem=mensagem(erro), duracao=round(time.monotonic() - relogio, 1))
                log(f"[{nome}] ERRO, migração interrompida (após {formatar_duracao(r['duracao'])}): {r['mensagem']}")
                log(traceback.format_exc(limit=2))
                raise _Parar()
            if not simular:
                con_pg.commit()
            r["relatorio"] = _relatorio(pasta_exec, e, detalhes)
            r["relatorio_erros"] = _relatorio_erros(pasta_exec, e, detalhes)
            todos_nao = r.pop("_nao_lidos_todos", None)
            if todos_nao:
                arq = pasta_exec / f"{e.id.replace('/', '__')}_nao_migrados.csv"
                with arq.open("w", newline="", encoding="utf-8-sig") as f:
                    w = csv.DictWriter(f, fieldnames=list(todos_nao[0].keys()), delimiter=";")
                    w.writeheader()
                    w.writerows(todos_nao)
                r["relatorio_nao_lidos"] = arq.name
            r["duracao"] = round(time.monotonic() - relogio, 1)    # leitura + gravacao + commit da etapa
            r["status"] = "concluido_com_erros" if r["erros"] else "concluido"
            log(f"[{nome}] fim: lidos {r['lidos']}, inseridos {r['inseridos']}, atualizados "
                f"{r['atualizados']}, sem alteração {r['sem_alteracao']}, pulados {r['pulados']}, "
                f"erros {r['erros']} — concluído em {formatar_duracao(r['duracao'])}")
    except _Parar:
        pass
    finally:
        if depara is not None:                 # planilhas finais da virada (antes de desfazer a simulacao)
            try:
                estado["arquivos_virada"] = depara.planilhas(con_pg, pasta_exec, estado.get("banco", "banco"))
                log("Planilhas de codigos da virada geradas: " + ", ".join(estado["arquivos_virada"]))
            except Exception as erro:
                con_pg.rollback()
                log(f"ERRO ao gerar as planilhas de codigos da virada: {mensagem(erro)}")
        if simular:
            con_pg.rollback()
            log("SIMULAÇÃO: tudo desfeito, nada foi gravado no PostgreSQL.")
        _finalizar(fila, con_pg, log)


def _finalizar(fila, con_pg, log) -> None:
    """Roda os finalizar.sql de todas as etapas da execucao, MESMO se algo falhou no meio
    (ex.: religar as triggers da tabela produto). Cada um num commit proprio."""
    vistos = set()
    for _m, e, nome in fila:
        sql = e.sql("finalizar.sql")
        if not sql or e.id in vistos:
            continue
        vistos.add(e.id)
        try:
            con_pg.rollback()            # descarta qualquer transacao pela metade
            con_pg.execute(sql)
            con_pg.commit()
            log(f"[{nome}] finalizar.sql executado")
        except Exception as erro:
            con_pg.rollback()
            log(f"[{nome}] ERRO no finalizar.sql: {mensagem(erro)}")


class _Parar(Exception):
    pass


RE_OPCAO = re.compile(r":(opcao|param)_(\w+)")
# Ancora do filtro de produto: toda selecao ligada a produto tem o trecho da opcao "fora de linha". Com a opcao
# "Somente produtos com movimentacao desde <data>" marcada, o motor acrescenta logo depois dele o filtro de movimento.
RE_FORA_DE_LINHA = re.compile(r"\(\s*COALESCE\((?:(\w+)\.)?PROFORLIN,\s*'N'\)\s*=\s*'N'\s+OR\s+:opcao_fora_de_linha\s*=\s*1\s*\)", re.I)
RE_MOVIMENTADO = re.compile(r"/\*\s*MOVIMENTADO\((\w*)\)\s*\*/", re.I)


def filtro_movimentacao(alias: str = "") -> str:
    """Produto com movimento desde :param_mov_data (consulta usada pela equipe, conferida no dicionario do SysPDV):
    venda no PDV (ITEVDA.TRNDAT), nota fiscal (NOTAFISCAL.NFSDATEMI), movimentacao de estoque de venda/entrada/
    cancelamento/troca/nota (ESTOQUE_MOVIMENTACAO.MOVTIP V,E,C,T,N) ou cadastrado/entrou em linha (PRODATCADINC).
    A data vai como PARAMETRO: o texto '10.11.2026' pode virar 11/10 no SQL Server (mes/dia)."""
    a = f"{alias}." if alias else ""
    return (f"({a}PROCOD IN (SELECT iv.PROCOD FROM ITEVDA iv WHERE iv.TRNDAT >= :param_mov_data)"
            f" OR {a}PROCOD IN (SELECT inf.PROCOD FROM ITEM_NOTA_FISCAL inf JOIN NOTAFISCAL nf ON nf.NFSCTR = inf.NFSCTR"
            f" WHERE nf.NFSDATEMI >= :param_mov_data)"
            f" OR {a}PROCOD IN (SELECT em.PROCOD FROM ESTOQUE_MOVIMENTACAO em WHERE em.MOVTIP IN ('V', 'E', 'C', 'T', 'N')"
            f" AND em.MOVDAT >= :param_mov_data)"
            f" OR {a}PRODATCADINC >= :param_mov_data)")


def _data_movimentacao(opcoes: dict):
    """Data da opcao 'movimentacao' (None = opcao desmarcada ou sem data)."""
    import datetime as _dt
    if not opcoes.get("movimentacao") or not opcoes.get("movimentacao_data"):
        return None
    v = opcoes["movimentacao_data"]
    return v if isinstance(v, _dt.date) else _dt.date.fromisoformat(str(v)[:10])
RE_FROM = re.compile(r"\bFROM\s+([A-Za-z_][\w$]*)", re.IGNORECASE)


def _sql_com_opcoes(sql: str, opcoes: dict) -> tuple[str, list]:
    """Troca :opcao_x por ? com 1/0 (opcao desconhecida = 0) e :param_x pelo valor. Com a opcao de movimentacao
    marcada, acrescenta o filtro de movimento depois da ancora "fora de linha" e troca /*MOVIMENTADO(alias)*/."""
    data_mov = _data_movimentacao(opcoes)
    if data_mov:
        sql = RE_FORA_DE_LINHA.sub(lambda m: f"{m.group(0)} AND {filtro_movimentacao(m.group(1) or '')}", sql)
    sql = RE_MOVIMENTADO.sub(lambda m: filtro_movimentacao(m.group(1)) if data_mov else "(1 = 1)", sql)
    valores = []
    parametros = {"mov_data": data_mov}

    def troca(m):
        if m.group(1) == "param":
            valores.append(parametros.get(m.group(2)))
        else:
            valores.append(1 if opcoes.get(m.group(2)) else 0)
        return "?"
    return RE_OPCAO.sub(troca, sql), valores


def _tabela_principal(sql: str) -> str | None:
    """Primeira tabela do FROM PRINCIPAL: ignora FROM dentro de parenteses (subconsultas
    como "(SELECT MAX(SECCOD) FROM SECAO)") e dentro de textos entre aspas."""
    sem_textos = re.sub(r"'[^']*'", "''", sql)
    profundidade, inicio = 0, 0
    for i, ch in enumerate(sem_textos):
        if ch == "(":
            profundidade += 1
        elif ch == ")":
            profundidade -= 1
        elif profundidade == 0 and i >= inicio:
            achou = RE_FROM.match(sem_textos, i) if sem_textos[i] in "Ff" else None
            if achou and (i == 0 or not (sem_textos[i - 1].isalnum() or sem_textos[i - 1] == "_")):
                return achou.group(1)
    return None


def _como_int(v):
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return v


def _chave_bruta(m: Etapa, linha: dict) -> str:
    """Chave do registro direto da linha lida (quando a transformacao falhou antes de montar a chave)."""
    vals = [str(linha.get(c)).strip() for c in (m.chave or []) if linha.get(c) is not None]
    if not vals:                                   # chave com outro nome na origem: primeira coluna da selecao
        primeiro = next(iter(linha.values()), None)
        vals = [str(primeiro).strip()] if primeiro is not None else []
    return "|".join(vals)


def _sem_order_by(sql: str) -> str:
    """Tira o ';' e o ORDER BY final (o SQL Server nao aceita ORDER BY dentro de subconsulta)."""
    sql = re.sub(r";\s*$", "", sql.strip())
    return re.sub(r"\border\s+by\b(?![^()]*\))(?!.*\border\s+by\b)[^()]*$", "", sql, flags=re.I | re.S).rstrip()


def _contar_origem(m: Etapa, con_fb, sql_origem: str, opcoes: dict | None = None):
    """"Na origem": por padrao conta EXATAMENTE o que a selecao (origem.sql) le, com os mesmos filtros e opcoes -
    assim "Nao migrados" so aparece quando um registro lido da erro ou e pulado. Um contagem_origem explicito no
    modulo.json (hoje so o Produto, que lista os "nao migrados pela regra da selecao") ou tabela_origem mudam isso."""
    if m.sem_contagem_origem:
        return None
    if m.contagem_origem:
        sql, valores = _sql_com_opcoes(m.contagem_origem, opcoes or {})
    elif m.tabela_origem:
        sql, valores = f"SELECT COUNT(*) FROM {m.tabela_origem}", None
    else:
        base, valores = _sql_com_opcoes(sql_origem, opcoes or {})
        base = "\n".join(l for l in base.splitlines() if not l.strip().startswith("--"))
        sql = f"SELECT COUNT(*) FROM ({_sem_order_by(base)}) contagem"
    try:
        cur = con_fb.cursor()
        cur.execute(sql, valores) if valores else cur.execute(sql)
        total = cur.fetchone()[0]
        cur.close()
        return total
    except Exception:
        try:
            con_fb.rollback()
        except Exception:
            pass
        return None


def _executar_modulo(m: Etapa, con_fb, con_pg, r: dict, log, nome: str,
                     opcoes: dict[str, bool] | None = None, dialeto: str = "firebird", depara=None) -> list[dict]:
    opcoes = opcoes or {}
    params_pg = {f"opcao_{k}": v for k, v in opcoes.items()}
    transformar = m.carregar_transformar()
    # garante uma transacao aberta: assim cada "with con_pg.transaction()" abaixo vira
    # um SAVEPOINT (e nao um COMMIT proprio), e a simulacao consegue desfazer tudo
    con_pg.execute("SELECT 1")
    sql_validar, sql_existe = m.sql("validar.sql"), m.sql("existe.sql")
    sql_inserir, sql_atualizar = m.sql("inserir.sql"), m.sql("atualizar.sql")
    if (antes := m.sql("antes.sql")):
        con_pg.execute(antes)
        log(f"[{nome}] antes.sql executado")

    if m.sql("origem.sql") is None:                      # item so de SQL
        if (depois := m.sql("depois.sql")):
            con_pg.execute(depois)
            log(f"[{nome}] depois.sql executado")
        return []

    # origem.sql serve para Firebird e SQL Server; origem.sqlserver.sql (se existir) e usado no SQL Server
    texto_origem = (m.sql(f"origem.{dialeto}.sql") if dialeto != "firebird" else None) or m.sql("origem.sql")
    r["total_origem"] = _contar_origem(m, con_fb, texto_origem, opcoes)
    sql_origem, valores_origem = _sql_com_opcoes(texto_origem, opcoes)
    cur = con_fb.cursor()
    try:
        cur.execute(sql_origem, valores_origem) if valores_origem else cur.execute(sql_origem)
    except Exception as erro:
        if not m.ignorar_se_origem_falhar:
            raise
        r["mensagem"] = _motivo_origem(erro)
        log(f"[{nome}] AVISO: {r['mensagem']}")
        return []
    colunas = [d[0].strip().lower() for d in cur.description]
    detalhes = []
    produtos_vf = None
    if m.exige_produto:
        # produtos que existem no VarejoFacil: um registro de produto que nao foi migrado (sem descricao, erro no
        # Produto...) e PULADO com o motivo, em vez de dar erro de chave em cada tabela ligada a produto
        produtos_vf = {int(r[0]) for r in con_pg.execute("SELECT procod FROM produto").fetchall()}
    while (lote := cur.fetchmany(500)):
        for bruta in lote:
            r["lidos"] += 1
            linha = dict(zip(colunas, bruta))
            item = {"status": "", "mensagem": ""}
            try:
                dados = transformar(dict(linha)) if transformar else linha
                aviso = dados.pop("_aviso", None) if isinstance(dados, dict) else None
                if depara is not None and isinstance(dados, dict):
                    aviso = _aplicar_depara(m, dados, depara, aviso)
                if params_pg and isinstance(dados, dict):
                    dados = {**params_pg, **dados}      # %(opcao_x)s nos .sql do Postgres
                item["chave"] = "|".join(str(dados.get(c)) for c in m.chave) if m.chave else ""
                if produtos_vf is not None:
                    for campo in m.exige_produto:
                        v = dados.get(campo)
                        if v not in (None, "") and _como_int(v) not in produtos_vf:
                            raise Pular(f"produto {v} não foi migrado para o VarejoFácil (veja o cartão do Produto): registro ignorado")
                with con_pg.transaction():  # savepoint da linha
                    if sql_validar and con_pg.execute(sql_validar, dados).fetchone() is None:
                        raise (Pular if m.validar_pula else ErroValidacao)(m.mensagem_validacao)
                    atual = None
                    if sql_existe:
                        cur_pg = con_pg.execute(sql_existe, dados)
                        linha_pg = cur_pg.fetchone()
                        if linha_pg is not None:
                            atual = dict(zip([d.name for d in cur_pg.description], linha_pg))
                    if atual is None:
                        con_pg.execute(sql_inserir, dados)
                        item["status"] = "inserido"
                        r["inseridos"] += 1
                    else:
                        mudou = {c: (atual[c], dados[c]) for c in atual if c in dados and not _iguais(atual[c], dados[c])}
                        if mudou and sql_atualizar:
                            con_pg.execute(sql_atualizar, dados)
                            item["status"] = "atualizado"
                            item["mensagem"] = "; ".join(f"{c}: {a!r} -> {n!r}" for c, (a, n) in mudou.items())
                            r["atualizados"] += 1
                        else:
                            item["status"] = "sem_alteracao"
                            r["sem_alteracao"] += 1
                    if aviso:
                        item["mensagem"] = f"{aviso}; {item['mensagem']}" if item["mensagem"] else aviso
                        r["avisos"] = r.get("avisos", 0) + 1
                        if len(r["amostra_avisos"]) < 50:
                            r["amostra_avisos"].append({"chave": item.get("chave") or f"linha {r['lidos']}", "mensagem": aviso})
            except Pular as e:
                item.update(status="pulado", mensagem=str(e))
                r["pulados"] += 1
                if not item.get("chave"):
                    item["chave"] = _chave_bruta(m, linha) or f"linha {r['lidos']}"
                if len(r["amostra_pulados"]) < 50:
                    r["amostra_pulados"].append({"chave": item["chave"], "mensagem": item["mensagem"]})
            except Exception as e:
                item.update(status="erro", mensagem=mensagem(e),
                            tecnico=" | ".join(l.strip() for l in str(e).splitlines() if l.strip())[:500])
                r["erros"] += 1
                if not item.get("chave"):
                    item["chave"] = _chave_bruta(m, linha)
                if len(r["amostra_erros"]) < 50:               # a tela mostra estes no cartao da tabela
                    r["amostra_erros"].append({"chave": item.get("chave") or f"linha {r['lidos']}",
                                               "mensagem": item["mensagem"]})
                if r["erros"] <= 5:
                    log(f"[{nome}] erro na linha {item.get('chave') or r['lidos']}: {item['mensagem']}")
                elif r["erros"] == 6:
                    log(f"[{nome}] ... mais erros: veja a lista no cartão da tabela ou a planilha só com os erros")
            item.setdefault("chave", "")
            item["origem"] = json.dumps(linha, default=str, ensure_ascii=False)
            detalhes.append(item)
    cur.close()
    if r.get("total_origem") is None and not m.sem_contagem_origem and not m.contagem_origem and not m.tabela_origem:
        # a contagem pela subconsulta nao rodou (ex.: coluna sem nome/repetida na selecao): o total da selecao e
        # exatamente o que foi lido
        r["total_origem"] = r["lidos"]
    if (txt_nao := m.sql("nao_lidos.sql")):
        # registros da tabela de origem que a selecao (origem.sql) deixa de fora, com o motivo: a tela mostra
        # quais sao os "Nao migrados" que nem foram lidos (ex.: produto sem descricao, codigo zerado)
        try:
            sql_nao, val_nao = _sql_com_opcoes(txt_nao, opcoes)
            cur_n = con_fb.cursor()
            cur_n.execute(sql_nao, val_nao) if val_nao else cur_n.execute(sql_nao)
            cols = [d[0].strip().lower() for d in cur_n.description]
            todos_nao = [dict(zip(cols, [str(v).strip() if v is not None else "" for v in l])) for l in cur_n.fetchall()]
            cur_n.close()
            r["nao_lidos_total"] = len(todos_nao)
            r["nao_lidos"] = todos_nao[:50]
            r["_nao_lidos_todos"] = todos_nao                  # vira planilha no fim da etapa (nao vai para a tela)
            if todos_nao:
                log(f"[{nome}] {len(todos_nao)} registro(s) ficaram de fora pela regra da seleção: veja o cartão da tabela")
        except Exception as erro:
            log(f"[{nome}] AVISO: não consegui listar os registros que ficaram de fora ({mensagem(erro)})")
    if (depois := m.sql("depois.sql")):
        con_pg.execute(depois)
        log(f"[{nome}] depois.sql executado")
    return detalhes


def _iguais(banco, novo) -> bool:
    """Compara o valor do VarejoFacil com o novo sem cair em diferenca so de tipo:
    0 = '0' = Decimal('0.00'), e 'N ' = 'N' (CHAR com espacos a direita)."""
    if banco == novo:
        return True
    if banco is None or novo is None or isinstance(banco, bool) or isinstance(novo, bool):
        return False
    if isinstance(banco, (date, datetime)) and isinstance(novo, (date, datetime)):
        # SQL Server devolve datetime onde o Firebird devolve date: 01/02 00:00 = 01/02
        para_dt = lambda v: v if isinstance(v, datetime) else datetime(v.year, v.month, v.day)
        return para_dt(banco).replace(tzinfo=None) == para_dt(novo).replace(tzinfo=None)
    try:
        return Decimal(str(banco).strip()) == Decimal(str(novo).strip())
    except (InvalidOperation, ValueError):
        pass
    if isinstance(banco, str) and isinstance(novo, str):
        return banco.rstrip() == novo.rstrip()
    return False


def _motivo_origem(erro) -> str:
    """Mensagem curta quando a origem nao tem a informacao (SysPDV de versao antiga)."""
    texto = str(erro).replace("\\n", "\n")
    achou = re.search(r"(Column|Table) unknown\W+(?:-\s*)?([\w.$]+)", texto)
    if achou:
        oque = "a coluna" if achou.group(1) == "Column" else "a tabela"
        return f"o SysPDV não tem {oque} {achou.group(2)} - etapa ignorada, o fluxo continua"
    achou = re.search(r"Invalid (column|object) name '([^']+)'", texto)          # SQL Server
    if achou:
        oque = "a coluna" if achou.group(1) == "column" else "a tabela"
        return f"o SysPDV não tem {oque} {achou.group(2)} - etapa ignorada, o fluxo continua"
    return f"informação não encontrada no SysPDV - etapa ignorada, o fluxo continua ({texto.splitlines()[0][:120]})"


def _aplicar_depara(m: Etapa, dados: dict, depara, aviso):
    """Virada: troca codigo do SysPDV (antigo) pelo do VarejoFacil (novo) nos campos declarados."""
    for campo, tipo in m.depara.items():
        if campo in dados and dados[campo] is not None:
            dados[campo] = depara.traduzir(tipo, dados[campo])
    g = m.depara_gera
    if g and g.get("campo") in dados and dados[g["campo"]] is not None:
        antigo = dados[g["campo"]]
        balanca = bool(g.get("balanca")) and str(dados.get(g["balanca"]) or "").strip() == "S"
        candidatos = ()
        if g.get("reaproveitar") and depara.con is not None:   # registro que ja existe (ex.: mesmo CPF/CNPJ)
            with depara.con.transaction():
                candidatos = [r[0] for r in depara.con.execute(g["reaproveitar"], dados).fetchall()]
        novo = depara.traduzir(g["tipo"], antigo, gerar=True, manter=balanca, candidatos=candidatos)
        dados[g["campo"]] = novo
        if novo != antigo:
            texto = f"codigo SysPDV {antigo} -> VarejoFacil {novo}"
            aviso = f"{aviso}; {texto}" if aviso else texto
    return aviso


def _relatorio(pasta: Path, m: Etapa, detalhes: list[dict]) -> str:
    arquivo = pasta / f"{m.id.replace('/', '__')}.csv"
    with arquivo.open("w", newline="", encoding="utf-8-sig") as f:  # abre certo no Excel
        w = csv.DictWriter(f, fieldnames=["chave", "status", "mensagem", "origem"], delimiter=";", extrasaction="ignore")
        w.writeheader()
        w.writerows(detalhes)
    return arquivo.name


def _relatorio_erros(pasta: Path, m: Etapa, detalhes: list[dict]) -> str | None:
    """Planilha SO com os registros que deram erro (chave, motivo e os dados que vieram da origem)."""
    erros = [d for d in detalhes if d.get("status") == "erro"]
    if not erros:
        return None
    arquivo = pasta / f"{m.id.replace('/', '__')}_erros.csv"
    with arquivo.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=["chave", "mensagem", "tecnico", "origem"], delimiter=";", extrasaction="ignore")
        w.writeheader()
        w.writerows(erros)
    return arquivo.name


def _traduzir_erro_pg(e: Exception) -> str | None:
    """Erros mais comuns do PostgreSQL ao gravar, em portugues claro (None = sem traducao)."""
    estado = getattr(e, "sqlstate", None)
    diag = getattr(e, "diag", None)
    detalhe = (getattr(diag, "message_detail", None) or "") if diag else ""
    tabela = (getattr(diag, "table_name", None) or "") if diag else ""
    coluna = (getattr(diag, "column_name", None) or "") if diag else ""
    import re as _re
    chave = _re.search(r"Key \((.+?)\)=\((.*?)\)", detalhe)
    if estado == "23503" and chave:                       # chave estrangeira
        ref = _re.search(r'table "([^"]+)"', detalhe)
        if "is not present" in detalhe:
            return (f"{chave.group(1)} {chave.group(2)} não existe na tabela {ref.group(1) if ref else '?'} do VarejoFácil "
                    "(o registro de que ele depende não foi migrado)")
        return f"{chave.group(1)} {chave.group(2)} ainda é usado na tabela {ref.group(1) if ref else '?'}: não pode ser apagado"
    if estado == "23505" and chave:                       # unico
        return f"já existe outro registro com {chave.group(1)} = {chave.group(2)} na tabela {tabela or '?'}"
    if estado == "23502":                                 # NOT NULL
        return f"o campo {coluna or '?'} da tabela {tabela or '?'} é obrigatório e veio vazio"
    if estado == "22001":
        return "um texto é maior que o tamanho do campo no VarejoFácil"
    if estado == "22003":
        return "um número é maior do que o campo do VarejoFácil aceita"
    if estado == "22P02":
        return f"valor em formato inválido para o campo ({str(e).splitlines()[0][:120]})"
    if estado == "23514":
        return f"o valor não passou numa regra (check) da tabela {tabela or '?'}"
    return None


def mensagem(e: Exception) -> str:
    """Erro legivel: o driver do Firebird devolve uma tupla com varias linhas."""
    traduzida = _traduzir_erro_pg(e)
    if traduzida:
        return traduzida
    if isinstance(e, KeyError):
        return f"campo {e.args[0]!r} nao existe na linha (confira o origem.sql e o transformar.py)"
    if e.args and isinstance(e.args[0], str) and "\n" in e.args[0]:
        partes = [l.strip(" -") for l in e.args[0].splitlines() if l.strip(" -")]
        partes = [l for l in partes if not l.startswith(("SQLCODE", "Dynamic SQL Error", "SQL error code"))]
        return " | ".join(partes)
    return str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__


def novo_id() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")
