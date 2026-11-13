"""Ajusta cada linha lida no origem.sql. As chaves do dicionario devolvido viram
os %(nomes)s usados no existe.sql, inserir.sql e atualizar.sql.
Os nomes das colunas do origem.sql chegam em minusculo (SECCOD -> seccod)."""
from app.ajudantes import inteiro, texto


def transformar(linha):
    return {
        "seccod": inteiro(linha["seccod"], "SECCOD"),                    # '01 ' -> 1
        "secdes": texto(linha["secdes"], maiusculo=True, vazio="RENOMEAR"),  # TRIM + MAIUSCULO
        "sec_situacao_sped": "OUTROS",                                     # fixo, como no Pentaho
    }
