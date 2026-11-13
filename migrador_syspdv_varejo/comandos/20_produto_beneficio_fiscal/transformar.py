"""
T-Produto_Codigo_Beneficio_fiscal_inicial: TRIM em tudo e codigo de beneficio em MAIUSCULO.
(A versao _virada do Pentaho perdeu esse tratamento; aqui vale nas duas.)
Na Migracao Virada, o motor troca o procod pelo codigo novo do arquivo de codigos de produtos
("depara" no modulo.json) - inclusive dos produtos novos da virada, que no Pentaho ficavam de fora
(Merge Join INNER com a planilha).
"""
from app.ajudantes import Pular, inteiro, texto


def transformar(linha):
    codigo = texto(linha["probenfis"])
    if not codigo:
        raise Pular("produto sem codigo de beneficio fiscal")
    return {
        "procod": inteiro(linha["procod"], "PROCOD"),
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "cpl_cbenef": codigo.upper(),
    }
