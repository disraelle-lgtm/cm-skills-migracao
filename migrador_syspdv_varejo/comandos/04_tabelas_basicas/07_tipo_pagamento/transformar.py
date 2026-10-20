from app.ajudantes import inteiro, texto


def transformar(linha):
    return {
        "tppcod": inteiro(linha["tppcod"], "TPPCOD"),
        "tppdes": texto(linha["tppdes"], maiusculo=True),   # TRIM + MAIUSCULO
        "tppvlrmax": linha["tppvlrmax"],
    }
