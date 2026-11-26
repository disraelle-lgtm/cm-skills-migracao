from app.ajudantes import inteiro


def transformar(linha):
    return {"tpdcod": inteiro(linha["tpdcod"], "TPDCOD"), "tpddes": linha["tpddes"]}
