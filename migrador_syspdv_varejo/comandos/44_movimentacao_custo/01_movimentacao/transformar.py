from datetime import date

from app.ajudantes import inteiro


def transformar(linha):
    return {"loj_codigo": inteiro(linha["prpcod"], "PRPCOD"), "procod": inteiro(linha["procod"], "PROCOD"),
            "custo_reposicao": linha["proprccst"], "custo_fiscal": linha["custo_fiscal"],
            "custo_medio": linha["custo_medio"], "data": date.today()}
