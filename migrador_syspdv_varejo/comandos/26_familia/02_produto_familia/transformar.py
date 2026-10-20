from app.ajudantes import inteiro


def transformar(linha):
    return {"codigo_produto": inteiro(linha["procod"], "PROCOD"),
            "codigo_familia": inteiro(linha["procodsim"], "PROCODSIM")}
