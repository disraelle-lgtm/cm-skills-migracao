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
import time
import re
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
import json
import traceback
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

from .ajudantes import Pular

RAIZ = Path(__file__).resolve().parent.parent
PASTA_COMANDOS = RAIZ / "comandos"
PASTA_RELATORIOS = RAIZ / "reports"

ARQUIVOS = ["modulo.json", "origem.sql", "origem.sqlserver.sql", "transformar.py", "validar.sql", "existe.sql",
            "inserir.sql", "atualizar.sql", "antes.sql", "depois.sql", "finalizar.sql"]
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
    opcoes: list[dict] = field(default_factory=list)   # checkboxes extras ao lado do item

    def para_dict(self) -> dict:
        return {"id": self.id, "nome": self.nome, "grupo": self.grupo, "descricao": self.descricao,
                "pasta": str(self.pasta.relative_to(RAIZ)),
                "etapas": [{"id": e.id, "nome": e.nome, "arquivos": e.arquivos()} for e in self.etapas],
                "arquivos": self.etapas[0].arquivos() if len(self.etapas) == 1 else [],
                "problemas": self.problemas + [f"{e.nome}: {p}" for e in self.etapas for p in e.problemas],
                "automatico_com_grupo": self.automatico_com_grupo, "automatico_sempre": self.automatico_sempre,
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
              tabela_origem=meta.get("tabela_origem"), contagem_origem=meta.get("contagem_origem"))
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
    extras = [m for m in todos if (m.automatico_com_grupo in grupos or m.automatico_sempre) and m not in escolhidos]
    return sorted(escolhidos + extras, key=lambda m: m.id)


def descobrir(pasta: Path = PASTA_COMANDOS) -> list[Modulo]:
    modulos = []
    for p in _visiveis(pasta) if pasta.exists() else []:
        meta = _ler_meta(p)
        m = Modulo(id=p.name, pasta=p, nome=meta.get("nome", p.name), grupo=meta.get("grupo", "Outros"),
                   descricao=meta.get("descricao", ""),
                   automatico_com_grupo=meta.get("automatico_com_grupo"),
                   automatico_sempre=bool(meta.get("automatico_sempre", False)),
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
def _vazio(nome: str) -> dict:
    return {"nome": nome, "status": "aguardando", "total_origem": None, "lidos": 0, "inseridos": 0, "atualizados": 0,
            "sem_alteracao": 0, "pulados": 0, "erros": 0, "relatorio": None, "mensagem": None,
            "inicio_ts": None, "fim_ts": None, "duracao_s": None}


def valores_opcoes(modulos: list[Modulo], escolhidas: dict | None) -> dict[str, bool]:
    """Padrao de cada opcao declarada nos modulos, sobreposto pelo que veio da tela."""
    valores = {o["id"]: bool(o.get("padrao", False)) for m in modulos for o in m.opcoes}
    for k, v in (escolhidas or {}).items():
        valores[k] = bool(v)
    return valores


def executar(modulos: list[Modulo], con_fb, con_pg, simular: bool, estado: dict,
             opcoes: dict[str, bool] | None = None, dialeto: str = "firebird") -> None:
    """Roda os itens e suas etapas em ordem. Real: commit ao fim de cada etapa.
    Simulacao: tudo numa transacao so, desfeita no final (as etapas seguintes enxergam
    o que as anteriores 'gravariam', ex.: o grupo ve as secoes novas)."""
    log = estado["log"].append
    pasta_exec = PASTA_RELATORIOS / estado["id"]
    pasta_exec.mkdir(parents=True, exist_ok=True)
    fila = []
    estado["inicio_ts"] = time.time()
    log(f"Migração iniciada em {datetime.now():%d/%m/%Y %H:%M:%S}")
    for m in modulos:
        for e in m.etapas:
            nome = m.nome if len(m.etapas) == 1 else f"{m.nome} › {e.nome}"
            estado["modulos"][e.id] = _vazio(nome)
            fila.append((m, e, nome))
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
            log(f"[{nome}] início às {datetime.now():%H:%M:%S} ({e.pasta.relative_to(RAIZ)})")
            try:
                detalhes = _executar_modulo(e, con_fb, con_pg, r, log, nome, opcoes or {}, dialeto)
            except Exception as erro:
                con_pg.rollback()
                _fechar_tempo(r)
                r.update(status="erro", mensagem=mensagem(erro))
                log(f"[{nome}] ERRO após {formatar_duracao(r['duracao_s'])}, migração interrompida: {r['mensagem']}")
                log(traceback.format_exc(limit=2))
                raise _Parar()
            if not simular:
                con_pg.commit()
            r["relatorio"] = _relatorio(pasta_exec, e, detalhes)
            r["status"] = "concluido_com_erros" if r["erros"] else "concluido"
            _fechar_tempo(r)
            log(f"[{nome}] fim em {formatar_duracao(r['duracao_s'])}: lidos {r['lidos']}, inseridos {r['inseridos']}, atualizados "
                f"{r['atualizados']}, sem alteração {r['sem_alteracao']}, pulados {r['pulados']}, "
                f"erros {r['erros']}")
    except _Parar:
        pass
    finally:
        if simular:
            con_pg.rollback()
            log("SIMULAÇÃO: tudo desfeito, nada foi gravado no PostgreSQL.")
        _finalizar(fila, con_pg, log)
        estado["fim_ts"] = time.time()
        estado["duracao_s"] = estado["fim_ts"] - estado["inicio_ts"]
        _resumo_tempos(estado, log)


def formatar_duracao(seg: float | None) -> str:
    if seg is None:
        return "-"
    if seg < 60:
        return f"{seg:.1f}s"
    h, resto = divmod(int(round(seg)), 3600)
    mi, se = divmod(resto, 60)
    return f"{h}h {mi:02d}min {se:02d}s" if h else f"{mi}min {se:02d}s"


def _fechar_tempo(r: dict) -> None:
    r["fim_ts"] = time.time()
    r["duracao_s"] = r["fim_ts"] - (r["inicio_ts"] or r["fim_ts"])


def _resumo_tempos(estado: dict, log) -> None:
    """Tempo de cada etapa (tabela) e o tempo total do processo, no log e em tempos.csv."""
    linhas = [(r["nome"], r["duracao_s"]) for r in estado["modulos"].values() if r["duracao_s"] is not None]
    log("---- Tempo por etapa ----")
    for nome, seg in linhas:
        log(f"  {nome}: {formatar_duracao(seg)}")
    log(f"Migração terminada em {datetime.now():%d/%m/%Y %H:%M:%S} — TEMPO TOTAL DA MIGRAÇÃO: "
        f"{formatar_duracao(estado['duracao_s'])}")
    try:
        with (PASTA_RELATORIOS / estado["id"] / "tempos.csv").open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f, delimiter=";")
            w.writerow(["etapa", "duracao_segundos", "duracao"])
            for nome, seg in linhas:
                w.writerow([nome, f"{seg:.2f}", formatar_duracao(seg)])
            w.writerow(["TOTAL", f"{estado['duracao_s']:.2f}", formatar_duracao(estado["duracao_s"])])
    except OSError:
        pass


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


RE_OPCAO = re.compile(r":opcao_(\w+)")
RE_FROM = re.compile(r"\bFROM\s+([A-Za-z_][\w$]*)", re.IGNORECASE)


def _sql_com_opcoes(sql: str, opcoes: dict[str, bool]) -> tuple[str, list]:
    """Troca :opcao_x por ? (parametro do Firebird) com 1/0. Opcao desconhecida = 0."""
    valores = []

    def troca(m):
        valores.append(1 if opcoes.get(m.group(1)) else 0)
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


def _contar_origem(m: Etapa, con_fb, sql_origem: str):
    """Total de registros da tabela de origem (sem os filtros do origem.sql)."""
    if m.contagem_origem:
        sql = m.contagem_origem
    else:
        tabela = m.tabela_origem or _tabela_principal(sql_origem)
        if not tabela:
            return None
        sql = f"SELECT COUNT(*) FROM {tabela}"
    try:
        cur = con_fb.cursor()
        cur.execute(sql)
        total = cur.fetchone()[0]
        cur.close()
        return total
    except Exception:
        return None


def _executar_modulo(m: Etapa, con_fb, con_pg, r: dict, log, nome: str,
                     opcoes: dict[str, bool] | None = None, dialeto: str = "firebird") -> list[dict]:
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
    r["total_origem"] = _contar_origem(m, con_fb, texto_origem)
    sql_origem, valores_origem = _sql_com_opcoes(texto_origem, opcoes)
    cur = con_fb.cursor()
    cur.execute(sql_origem, valores_origem) if valores_origem else cur.execute(sql_origem)
    colunas = [d[0].strip().lower() for d in cur.description]
    detalhes = []
    while (lote := cur.fetchmany(500)):
        for bruta in lote:
            r["lidos"] += 1
            linha = dict(zip(colunas, bruta))
            item = {"status": "", "mensagem": ""}
            try:
                dados = transformar(dict(linha)) if transformar else linha
                aviso = dados.pop("_aviso", None) if isinstance(dados, dict) else None
                if params_pg and isinstance(dados, dict):
                    dados = {**params_pg, **dados}      # %(opcao_x)s nos .sql do Postgres
                item["chave"] = "|".join(str(dados.get(c)) for c in m.chave) if m.chave else ""
                with con_pg.transaction():  # savepoint da linha
                    if sql_validar and con_pg.execute(sql_validar, dados).fetchone() is None:
                        raise ErroValidacao(m.mensagem_validacao)
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
            except Pular as e:
                item.update(status="pulado", mensagem=str(e))
                r["pulados"] += 1
            except Exception as e:
                item.update(status="erro", mensagem=mensagem(e))
                r["erros"] += 1
                if r["erros"] <= 5:
                    log(f"[{nome}] erro na linha {item.get('chave') or r['lidos']}: {item['mensagem']}")
            item.setdefault("chave", "")
            item["origem"] = json.dumps(linha, default=str, ensure_ascii=False)
            detalhes.append(item)
    cur.close()
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


def _relatorio(pasta: Path, m: Etapa, detalhes: list[dict]) -> str:
    arquivo = pasta / f"{m.id.replace('/', '__')}.csv"
    with arquivo.open("w", newline="", encoding="utf-8-sig") as f:  # abre certo no Excel
        w = csv.DictWriter(f, fieldnames=["chave", "status", "mensagem", "origem"], delimiter=";")
        w.writeheader()
        w.writerows(detalhes)
    return arquivo.name


def mensagem(e: Exception) -> str:
    """Erro legivel: o driver do Firebird devolve uma tupla com varias linhas."""
    if isinstance(e, KeyError):
        return f"campo {e.args[0]!r} nao existe na linha (confira o origem.sql e o transformar.py)"
    if e.args and isinstance(e.args[0], str) and "\n" in e.args[0]:
        partes = [l.strip(" -") for l in e.args[0].splitlines() if l.strip(" -")]
        partes = [l for l in partes if not l.startswith(("SQLCODE", "Dynamic SQL Error", "SQL error code"))]
        return " | ".join(partes)
    return str(e).strip().splitlines()[0] if str(e).strip() else type(e).__name__


def novo_id() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")
