from app.ajudantes import inteiro


def transformar(linha):
    # as 3 saidas do Switch/Case do Pentaho gravam exatamente os mesmos campos
    return {
        "enccod": inteiro(linha["enccod"], "ENCCOD"),
        "procod": inteiro(linha["procod"], "PROCOD"),
        "encproprcofe_preco_1": linha["encproprcofe"],
        "encproprcofe_preco_2": linha["proprcofe2"],
        "encproprcofe_preco_3": linha["proprcofe3"],
    }
