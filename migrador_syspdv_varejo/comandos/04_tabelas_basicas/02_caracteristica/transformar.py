from app.ajudantes import inteiro


def transformar(linha):
    return {"ctecod": inteiro(linha["ctecod"], "CTECOD"), "ctedes": linha["ctedes"]}
