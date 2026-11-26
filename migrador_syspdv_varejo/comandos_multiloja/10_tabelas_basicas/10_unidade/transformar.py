def transformar(linha):
    codigo = (linha["undcod"] or "").rstrip().upper()   # trim: so a direita + MAIUSCULO
    fator = linha["undfatref"]
    return {
        "undcod": codigo,
        "unddes": linha["unddes"],
        "undfatref": 1 if fator is None else fator,      # If null: UNDFATREF = 1
    }
