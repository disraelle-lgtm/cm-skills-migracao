"""
Relatorio padrao do kit-migracao (3-menu-migracao/app/relatorios/varejo.py, opcao "Gerar relatorio padrao" do
banco VarejoFacil): as tres listagens em CSV (';' + cabecalho), com os MESMOS nomes de arquivo e as MESMAS consultas
do kit. Diferencas: consulta pelo psycopg (o kit usava \\copy do psql), CSV em UTF-8 com BOM (acentos certos no
Excel) e um .zip com os tres para baixar de uma vez.
"""
from __future__ import annotations

import csv
import time
import zipfile
from pathlib import Path

RELATORIOS_PADRAO = [
    (
        "LISTAGEM DOS PRODUTOS PRECO ZERO.csv",     # no kit estava "LISTAR DOS ..." (corrigido a pedido do usuario)
        """
        SELECT p.procod AS "CÓDIGO PRODUTO",
               p.prodes AS "DESCRIÇÃO PRODUTO",
               p2.prcvdavar AS "PREÇO"
        FROM produto p
        JOIN preco p2 ON p.procod = p2.procod
        WHERE p.procod NOT IN (SELECT procod FROM preco WHERE prcvdavar != 0)
        """,
    ),
    (
        "LISTAGEM DOS PRODUTOS QUE O NCM ESTA INATIVO.csv",
        """
        SELECT p.procod AS "CÓDIGO PRODUTO",
               p.prodes AS "DESCRIÇÃO",
               p.prONcm AS "NCM"
        FROM produto p
        JOIN ncm n ON p.prONcm = n.ncm_codigo
        WHERE (n.ncm_descricao = 'NCM INATIVO' OR n.ncm_ativo IS FALSE)
          AND ncm_ativo = FALSE
        ORDER BY 1
        """,
    ),
    (
        "LISTAGEM DOS PRODUTOS UNIDADE DE MEDIDA ERRADO.csv",
        # (v2026.11.54) o migrador NAO corrige mais peso variavel / balanca (vem como no SysPDV): a listagem mostra TODOS
        # os casos incoerentes, com o motivo (o kit listava so peso variavel + balanca com unidade diferente de KG).
        # Peso variavel = S, P ou D (como no envio ao Panama).
        """
        SELECT procod AS "CODIGO PRODUTO",
               prodes AS "DESCRIÇÃO",
               TRIM(prounid) AS "UNIDADE VENDA",
               TRIM(proundcmp) AS "UNIDADE COMPRA",
               propesvar AS "PESO VARIAVEL",
               proenvbal AS "ENVIA PARA BALANÇA",
               CONCAT_WS(' | ',
                   CASE WHEN pesavel AND COALESCE(TRIM(prounid), '') <> 'KG' THEN 'peso variável com unidade de venda diferente de KG' END,
                   CASE WHEN NOT pesavel AND TRIM(prounid) = 'KG' THEN 'unidade de venda KG sem peso variável' END,
                   CASE WHEN NOT pesavel AND proenvbal = 'S' THEN 'enviado à balança sem peso variável' END,
                   CASE WHEN pesavel AND COALESCE(proenvbal, 'N') <> 'S' THEN 'peso variável sem envio à balança' END
               ) AS "MOTIVO"
        FROM (SELECT p.*, COALESCE(p.propesvar, 'N') IN ('S', 'P', 'D') AS pesavel FROM produto p) x
        WHERE (pesavel AND COALESCE(TRIM(prounid), '') <> 'KG')
           OR (NOT pesavel AND TRIM(prounid) = 'KG')
           OR (NOT pesavel AND proenvbal = 'S')
           OR (pesavel AND COALESCE(proenvbal, 'N') <> 'S')
        ORDER BY procod
        """,
    ),
]


def gerar(con_pg, pasta_base: Path, banco: str) -> dict:
    """Gera os tres CSV numa pasta nova + o .zip. Devolve {pasta, arquivos: [{nome, linhas, erro}], zip}."""
    pasta = Path(pasta_base) / time.strftime(f"relatorio_padrao_%Y%m%d_%H%M%S")
    pasta.mkdir(parents=True, exist_ok=True)
    arquivos = []
    for nome, sql in RELATORIOS_PADRAO:
        item = {"nome": nome, "linhas": None, "erro": None}
        try:
            with con_pg.transaction():
                cur = con_pg.execute(sql)
                colunas = [c.name for c in cur.description]
                linhas = cur.fetchall()
            with (pasta / nome).open("w", newline="", encoding="utf-8-sig") as f:
                w = csv.writer(f, delimiter=";")
                w.writerow(colunas)
                w.writerows(linhas)
            item["linhas"] = len(linhas)
        except Exception as e:
            item["erro"] = str(e).splitlines()[0][:200]
        arquivos.append(item)
    nome_zip = f"Relatório padrão - {banco}.zip"
    with zipfile.ZipFile(pasta / nome_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for a in arquivos:
            if a["linhas"] is not None:
                z.write(pasta / a["nome"], a["nome"])
    return {"pasta": pasta.name, "arquivos": arquivos, "zip": nome_zip}
