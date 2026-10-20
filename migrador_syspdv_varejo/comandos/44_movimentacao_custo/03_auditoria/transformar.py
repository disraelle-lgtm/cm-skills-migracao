from datetime import date

from app.ajudantes import inteiro


def transformar(linha):
    return {"loj_codigo": inteiro(linha["prpcod"], "PRPCOD"), "procod": inteiro(linha["procod"], "PROCOD"),
            "ac_custo_reposicao": linha["proprccst"], "ac_custo_fiscal": linha["proprccstfis"], "data": date.today()}
