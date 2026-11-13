"""
Consultar e ajustar codigos de clientes e produtos no VarejoFacil (tela "3. Consultar codigos").

Mesma logica do "Submenu Correcao" do kit-migracao (app/correcao/cliente.py e produto.py):
os scripts ajusta_cliente.sql e ajusta_produto.sql desta pasta sao os do kit, sem alteracao.

  Clientes: codigo >= 999999 (quebra o Varejo) recebe o menor codigo livre.
  Produtos: codigo >= 999999 (EAN no codigo principal), exceto balanca, recebe um codigo livre de
            10001 a 999998; o codigo antigo vira EAN do produto e vai para a alteracao_produto_sped.

Diferencas do kit:
  - roda pelo psycopg (sem psql): as linhas de comando do psql (\\echo, \\set) sao ignoradas e as
    mensagens RAISE NOTICE viram o log da tela;
  - TUDO numa transacao so (script + exportacao dos CSV + DROP da coluna auxiliar): se qualquer
    parte falhar, nada fica gravado (no kit o DROP e os CSV vinham depois do commit).
"""
from __future__ import annotations

import csv
import re
import io
from datetime import datetime
from pathlib import Path

PASTA = Path(__file__).resolve().parent
RAIZ = PASTA.parent.parent
PASTA_ARQUIVOS = RAIZ / "reports" / "codigos"

LIMITE = 999999                 # codigos >= isto quebram o Varejo
PRIMEIRO_PRODUTO = 10001        # produtos novos de 10001...
ULTIMO_PRODUTO = 999998         # ...ate 999998 (abaixo de 10001 e da balanca)

PREVIA = {
    "clientes": f"SELECT COUNT(*), COALESCE(MIN(cli_codigo), 0), COALESCE(MAX(cli_codigo), 0) "
                f"FROM pessoa_cliente WHERE cli_codigo >= {LIMITE}",
    "produtos": f"SELECT COUNT(*), COALESCE(MIN(procod), 0), COALESCE(MAX(procod), 0) "
                f"FROM produto WHERE procod >= {LIMITE} AND proenvbal = 'N'",
}

EXPORTA = {
    "clientes": {
        "script": "ajusta_cliente.sql",
        "base": ('SELECT pc.cli_codigo AS "CODIGO NOVO", pc.codigo_cliente_antigo AS "CODIGO ANTIGO", '
                 'p.pes_nome AS "NOME CLIENTE" FROM pessoa p JOIN pessoa_cliente pc ON p.pes_codigo = pc.pes_codigo'),
        "alterados": "pc.cli_codigo != pc.codigo_cliente_antigo",
        "arquivos": ("cod_novo_cod_antigo_cliente_todos_{banco}.csv", "cod_novo_cod_antigo_cliente_alterados_{banco}.csv"),
        "drop": "ALTER TABLE pessoa_cliente DROP COLUMN codigo_cliente_antigo",
    },
    "produtos": {
        "script": "ajusta_produto.sql",
        "base": ('SELECT p.procod AS "CODIGO NOVO", p.codigo_produto_antigo AS "CODIGO ANTIGO", '
                 'p.prodes AS "DESCRICAO" FROM produto p'),
        "alterados": "p.codigo_produto_antigo != p.procod",
        "arquivos": ("cod_novo_cod_antigo_produto_todos_{banco}.csv", "cod_novo_cod_antigo_produto_alterados_{banco}.csv"),
        "drop": "ALTER TABLE produto DROP COLUMN codigo_produto_antigo",
    },
}


def consultar(con, quais: list[str]) -> dict:
    """Previa (nada e alterado): quantos codigos >= 999999 e o menor/maior."""
    resultado = {q: consultar_sem_rollback(con, q) for q in quais}
    con.rollback()
    return resultado


def _nova_pasta(prefixo: str) -> Path:
    pasta = PASTA_ARQUIVOS / f"{prefixo}_{datetime.now().strftime('%Y%m%d_%H%M%S_%f')}"
    pasta.mkdir(parents=True, exist_ok=True)
    return pasta


def _escrever_csv(arquivo: Path, colunas, linhas) -> None:
    with open(arquivo, "w", newline="", encoding="utf-8-sig") as f:   # BOM: acentos certos no Excel
        w = csv.writer(f, delimiter=";")
        w.writerow(colunas)
        w.writerows(linhas)


def _script(nome: str) -> str:
    """Script do kit sem as linhas de comando do psql (\\echo, \\set ...)."""
    linhas = (PASTA / nome).read_text(encoding="utf-8").splitlines()
    return "\n".join(l for l in linhas if not l.lstrip().startswith("\\"))


def _csv(con, sql: str, arquivo: Path):
    cur = con.execute(sql)
    colunas = [d.name for d in cur.description]
    linhas = cur.fetchall()
    _escrever_csv(arquivo, colunas, linhas)
    return colunas, linhas


def ajustar(con, quais: list[str], banco: str, log, progresso: dict | None = None) -> dict:
    """Roda os scripts do kit e exporta os CSV. Tudo numa transacao: erro = nada gravado.
    progresso (opcional): {"tipos": {q: {total, feitos, pct, fase}}} atualizado ao vivo para a barra da tela -
    os scripts do kit avisam (RAISE NOTICE) a cada codigo trocado: troca = 0-85%, limpeza dos EAN e planilhas = o resto."""
    pasta = _nova_pasta("ajuste")
    tipos = (progresso or {}).setdefault("tipos", {})
    for q in quais:
        tipos.setdefault(q, {"total": 0, "feitos": 0, "pct": 0, "fase": "aguardando"})

    def fase(q, texto, pct=None):
        tipos[q]["fase"] = texto
        if pct is not None:
            tipos[q]["pct"] = pct

    def aviso(d):
        msg = d.message_primary or ""
        if msg.startswith(("CODIGO ANTIGO", "AJUSTANDO")):
            log(f"[{atual[0]}] {msg}")          # aparece na tela enquanto o script roda
            t = tipos.get(atual[0])
            if t is not None:                   # um aviso por codigo trocado -> barra de progresso real
                t["feitos"] += 1
                t["pct"] = round(85 * min(t["feitos"], t["total"]) / t["total"], 1) if t["total"] else 0
    atual = [""]
    con.add_notice_handler(aviso)
    resultado = {}
    try:
        for q in quais:
            cfg = EXPORTA[q]
            fase(q, "consultando os códigos")
            antes = consultar_sem_rollback(con, q)
            tipos[q]["total"] = antes["quantidade"]
            if antes["quantidade"] == 0:
                fase(q, "nada a alterar", 100)
                resultado[q] = {**antes, "alterados": 0, "arquivos": [],
                                "mensagem": f"Nenhum codigo >= {LIMITE}. Nada a alterar."}
                log(f"[{q}] nenhum codigo >= {LIMITE}: nada a alterar")
                continue
            log(f"[{q}] ajustando {antes['quantidade']} codigo(s) de {antes['menor']} a {antes['maior']}...")
            atual[0] = q
            fase(q, "trocando os códigos", 0)
            con.execute(_script(cfg["script"]))
            fase(q, "códigos trocados", 85)
            if q == "produtos":
                fase(q, "limpeza dos códigos de barras", 85)
                _limpeza_ean(con, log, lambda i, n: fase(q, f"limpeza dos códigos de barras ({i} de {n})", round(85 + 10 * i / n, 1)))
            fase(q, "gerando as planilhas", 95)
            todos, alterados = (pasta / n.format(banco=banco) for n in cfg["arquivos"])
            _csv(con, f"{cfg['base']} ORDER BY 1", todos)
            colunas, linhas = _csv(con, f"{cfg['base']} WHERE {cfg['alterados']} ORDER BY 1", alterados)
            # As FKs DEFERRABLE INITIALLY DEFERRED do VarejoFacil deixam conferencias pendentes depois da troca, e com
            # elas pendentes o PostgreSQL nao deixa alterar a tabela ("cannot ALTER TABLE ... because it has pending
            # trigger events"). SET CONSTRAINTS ALL IMMEDIATE confere AGORA (chave errada = erro e tudo desfeito).
            con.execute("SET CONSTRAINTS ALL IMMEDIATE")
            con.execute(cfg["drop"])
            con.execute("SET CONSTRAINTS ALL DEFERRED")
            resultado[q] = {**antes, "alterados": len(linhas),
                            # um botao "Download" na tela baixa os dois arquivos: todos e so os alterados
                            "arquivos": [f"{pasta.name}/{todos.name}", f"{pasta.name}/{alterados.name}"]}
            log(f"[{q}] {len(linhas)} codigo(s) alterado(s); planilhas geradas")
            fase(q, f"concluído — {len(linhas)} código(s) alterado(s)", 100)
        con.commit()
    except Exception:
        con.rollback()
        for f in pasta.glob("*.csv"):
            f.unlink()
        pasta.rmdir()                  # tentativa que falhou nao deixa pasta vazia
        raise
    return resultado


def _limpeza_ean(con, log, passo=None) -> None:
    """Depois da troca de codigos dos produtos: limpeza dos codigos auxiliares (limpeza_ean.sql, script do usuario).
    Executa passo a passo e registra no log quantos registros cada passo alterou."""
    texto = (PASTA / "limpeza_ean.sql").read_text(encoding="utf-8")
    partes = re.split(r"^-- PASSO: (.+)$", texto, flags=re.M)
    log("[produtos] limpeza dos códigos auxiliares (EAN) depois da troca:")
    passos = list(zip(partes[1::2], partes[2::2]))
    for i, (descricao, corpo) in enumerate(passos, 1):
        sql = "\n".join(l for l in corpo.splitlines() if not l.strip().startswith("--")).strip().rstrip(";")
        if not sql:
            continue
        cur = con.execute(sql)
        log(f"[produtos]   {descricao.strip()}: {cur.rowcount}")
        if passo:
            passo(i, len(passos))


def consultar_sem_rollback(con, q: str) -> dict:
    qtd, menor, maior = con.execute(PREVIA[q]).fetchone()
    return {"quantidade": int(qtd), "menor": int(menor), "maior": int(maior)}
