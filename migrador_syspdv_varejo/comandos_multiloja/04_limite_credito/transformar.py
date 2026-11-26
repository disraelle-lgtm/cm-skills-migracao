from app.ajudantes import inteiro


def transformar(linha):
    limite = linha["clilimcre"]
    return {
        "cli_codigo": inteiro(linha["clicod"], "CLICOD"),
        "lcr_valor": 0 if limite is None else limite,    # If null: 0
        "especie_boleto_receber": True,   # a especie e SEMPRE BOLETO RECEBER, procurada pelo nome no SQL (antes: codigo 2 fixo)
        "lcr_situacao": "LIBERADO",                       # Add constants
    }
