from app.ajudantes import inteiro


def transformar(linha):
    return {"ramcod": inteiro(linha["ramcod"], "RAMCOD"), "ramdes": linha["ramdes"]}
