"""
Regras do T-ProdutoPreco_inicial + "Corrige Precos Zerados" (aplicado aqui tambem, para a
2a rodada nao ficar "atualizando" o que o depois.sql ja corrigiu).
"""
from decimal import Decimal

from app.ajudantes import inteiro


def _zero_se_negativo(valor):
    return 0 if valor is not None and valor < 0 else valor


def transformar(linha):
    desconto = linha["prodcnmax"]
    if desconto is not None and desconto > 99:            # "Trata desconto maximo"
        desconto = Decimal("99.99")
    venda_var = linha["proprcvdavar"]
    return {
        "lojcod": inteiro(linha["prpcod"], "PRPCOD"),
        "procod": inteiro(linha["procod"], "PROCOD"),
        "prcdcnmax": desconto,
        "prcvdavar": 0 if venda_var is None else venda_var,           # "Trata precos negativos": nulo = 0
        "prcofevar": linha["proprcofevar"],
        "prcdtultre": linha["proprcdatalt"],
        "prccst": _zero_se_negativo(linha["proprccst"]),
        "prcvda2": linha["proprcvda2"],
        "prcofe2": linha["proprcofe2"],
        "prcvda3": linha["proprcvda3"],
        "prcofe3": linha["proprcofe3"],
        "prcpreco1": linha["proprc1"],
        "prcpreco2": linha["proprc2"],
        "prcpreco3": linha["proprc3"],
        "prcperdcn": linha["properdcn"],
        "prcmrg1": _zero_se_negativo(linha["promrg1"]),
        "prcmrg2": linha["promrg2"],
        "prcmrg3": linha["promrg3"],
        "proprccstmed": _zero_se_negativo(linha["proprccstmed"]),
        "proprccstfis": _zero_se_negativo(linha["proprccstfis"]),
        "prcqtdminprc2": linha["proqtdminprc2"],
        "prcqtdminprc3": linha["proqtdminprc3"],
    }
