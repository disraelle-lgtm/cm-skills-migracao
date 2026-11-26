from app.ajudantes import inteiro


def transformar(linha):
    return {"comp_procod": inteiro(linha["procod"], "PROCOD"),
            "comp_quantidade": linha["cmpqtd"], "comp_baixa": linha["cmpestven"]}
