from app.ajudantes import inteiro, texto


def transformar(linha):
    return {
        "seccod": inteiro(linha["seccod"], "SECCOD"),
        "grpcod": inteiro(linha["grpcod"], "GRPCOD"),
        "sgpcod": inteiro(linha["sgrcod"], "SGRCOD"),       # no VarejoFacil a coluna e sgpcod
        "sgpdes": texto(linha["sgrdes"], vazio="RENOMEAR"),
    }
