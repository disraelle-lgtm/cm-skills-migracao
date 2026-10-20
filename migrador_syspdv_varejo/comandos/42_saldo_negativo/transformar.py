from datetime import date

from app.ajudantes import inteiro


def transformar(linha):
    return {"procod": inteiro(linha["procod"], "PROCOD"), "loj_codigo": inteiro(linha["lojcod"], "LOJCOD"),
            "mov_quantidade": linha["saldo"], "mov_data": date.today()}
