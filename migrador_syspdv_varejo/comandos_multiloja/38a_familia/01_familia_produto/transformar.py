from app.ajudantes import inteiro


def transformar(linha):
    return {"codigo": inteiro(linha["procodsim"], "PROCODSIM"), "descricao": linha["similaresdes"]}
