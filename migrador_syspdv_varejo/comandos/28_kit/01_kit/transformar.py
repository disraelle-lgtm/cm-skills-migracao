"""T-Produto_Kit: quantidade 1, baixa 'P', tipo S = PRECO / N = FATOR (outros ficam como estao)."""
from app.ajudantes import inteiro, texto

TIPO = {"S": "PRECO", "N": "FATOR"}


def transformar(linha):
    tipo = texto(linha["cnttip"])
    return {"comp_procod": inteiro(linha["procod"], "PROCOD"), "comp_quantidade": 1, "comp_baixa": "P",
            "comp_tipo": TIPO.get(tipo, tipo)}
