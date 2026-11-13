from app.ajudantes import inteiro


def transformar(linha):
    return {
        "stacod": inteiro(linha["stacod"], "STACOD"),
        "stades": linha["stades"],
        "statipbloq": linha["stablq"],   # o Pentaho grava STABLQ nas duas colunas
        "stablc": linha["stablq"],
    }
