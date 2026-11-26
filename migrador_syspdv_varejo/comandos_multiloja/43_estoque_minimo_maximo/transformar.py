"""Maximo menor que o minimo vira o minimo (CASE do Pentaho); vazios = 0."""
from app.ajudantes import inteiro


def transformar(linha):
    minimo = linha["proestmin"] if linha["proestmin"] is not None else 0
    maximo = linha["proestmax"] if linha["proestmax"] is not None else 0
    if maximo < minimo:
        maximo = minimo
    return {"procod": inteiro(linha["procod"], "PROCOD"), "loj_codigo": inteiro(linha["lojcod"], "LOJCOD"),
            "peq_minimo": minimo, "peq_maximo": maximo}
