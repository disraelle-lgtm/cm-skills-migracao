from app.ajudantes import Pular, inteiro, numero, so_digitos, texto  # noqa: F401


def transformar(linha):
    # linha = {"codigo": "001 ", "descricao": "abc"}  (colunas do origem.sql, em minusculo)
    # Para nao migrar uma linha:  raise Pular("motivo")
    return {
        "codigo": inteiro(linha["codigo"], "CODIGO"),
        "descricao": texto(linha["descricao"], vazio="RENOMEAR"),
    }
