from app.ajudantes import inteiro, texto


def transformar(linha):
    return {
        "seccod": inteiro(linha["seccod"], "SECCOD"),
        "grpcod": inteiro(linha["grpcod"], "GRPCOD"),
        "grpdes": texto(linha["grpdes"], vazio="RENOMEAR"),  # so TRIM (o Pentaho nao poe em maiusculo)
    }
