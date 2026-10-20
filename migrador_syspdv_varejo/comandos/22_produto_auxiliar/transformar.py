"""
Regras do T-ProdutoAuxiliar_inicial:
  - PROCODAUX: TRIM e zeros a esquerda ate 14;
  - Filter rows: codigo com algum caractere que nao e digito -> LITERAL; so digitos -> EAN;
  - EAN: proauxcodigoean = 13 PRIMEIROS caracteres do codigo de 14 (Strings cut 0-13) como inteiro.
    ATENCAO: para um EAN-13 comum isso deixa de fora o ultimo digito - esta assim no Pentaho
    (confirmar se e intencional);
  - fator: 0 ou vazio = 1; tributado e principal = falso (a limpeza no depois.sql acerta).
"""
import re

from app.ajudantes import inteiro, texto


def transformar(linha):
    codigo = (texto(linha["procodaux"]) or "").rjust(14, "0")
    fator = linha["profatormult"]
    literal = bool(re.search(r"[^0-9]", codigo))
    return {
        "procodaux": codigo,
        "procod": inteiro(linha["procod"], "PROCOD"),
        "proauxfat": 1 if fator in (None, 0, "0", "") else fator,
        "proauxtipo": "LITERAL" if literal else "EAN",
        "proauxcodigoean": None if literal else int(codigo[:13]),
        "proeantrib": False,
        "proeanprinc": False,
        # so para o existe.sql (EAN igual ao codigo de um produto); a conversao fica aqui e nao no
        # SQL, porque o PostgreSQL pode tentar converter um codigo LITERAL e dar erro
        "codigo_numerico": None if literal else int(codigo),
    }
