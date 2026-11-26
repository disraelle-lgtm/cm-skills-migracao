from app.ajudantes import inteiro


def transformar(linha):
    return {
        "aplcod": inteiro(linha["aplcod"], "APLCOD"),   # Select values: APLCOD Integer
        "apldes": linha["apldes"],                      # sem tratamento no Pentaho
    }
