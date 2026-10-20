from app.ajudantes import inteiro


def transformar(linha):
    limite = linha["clilimcre"]
    return {
        "cli_codigo": inteiro(linha["clicod"], "CLICOD"),
        "lcr_valor": 0 if limite is None else limite,    # If null: 0
        "edc_codigo": 2,                                  # Add constants
        "lcr_situacao": "LIBERADO",                       # Add constants
    }
