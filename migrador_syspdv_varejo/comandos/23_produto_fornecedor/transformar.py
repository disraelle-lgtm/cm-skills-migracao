"""
Regras do T-ProdutoFornecedor_inicial e do "Limpa 0":
  - referencia (PRFREFFOR) com TRIM; vazia nao migra (Filter rows IS NOT NULL);
  - referencia so com digitos perde os zeros a esquerda ("VF - Limpa": CAST AS BIGINT) - feito
    aqui, antes de gravar, para a 2a rodada nao duplicar;
  - unidade e nivel em MAIUSCULO; vazios = UN / P; quantidade vazia = 1;
  - CNPJ/CPF do fornecedor so com digitos para achar o fornecedor no VarejoFacil (ver validar.sql).
"""
from app.ajudantes import Pular, inteiro, so_digitos, texto


def transformar(linha):
    referencia = texto(linha["prfreffor"])
    if not referencia:
        raise Pular("referencia do fornecedor vazia")
    if referencia.isdigit():
        referencia = str(int(referencia))              # "Limpa 0"
    return {
        "procod": inteiro(linha["procod"], "PROCOD"),
        "forcod": inteiro(linha["forcod"], "FORCOD"),
        "prfreffor": referencia,
        "prfunid": (texto(linha["prfunid"]) or "UN").upper(),
        "prfqtd": 1 if linha["prfqtd"] is None else linha["prfqtd"],
        "prfnivel": (texto(linha["prfnivel"]) or "P").upper(),
        "forcgc": so_digitos(linha["forcgc"]),
    }
