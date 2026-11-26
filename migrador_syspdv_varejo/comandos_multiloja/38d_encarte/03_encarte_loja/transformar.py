from app.ajudantes import inteiro


def transformar(linha):
    return {"enccod": inteiro(linha["enccod"], "ENCCOD"), "lojcod": inteiro(linha["prpcod"], "PRPCOD")}
