from app.ajudantes import texto


def transformar(linha):
    return {
        "mar_codigo": linha["mar_codigo"],                               # sem conversao no Pentaho
        "mar_descricao": texto(linha["mar_descricao"], maiusculo=True),  # String operations: TRIM + MAIUSCULO
    }
