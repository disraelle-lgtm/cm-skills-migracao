from app.ajudantes import inteiro, texto

COPIADOS = ["tprtip", "tprdcn", "tprnumaut", "tprprzrec", "tprprzjur", "tprprzmul", "tprperjur",
            "tprpermul", "tprtipjur", "tprimpdoc", "tprnumvia", "tprvlrfix"]


def transformar(linha):
    dados = {
        "tprcod": inteiro(linha["tprcod"], "TPRCOD"),
        "tprdes": texto(linha["tprdes"], maiusculo=True, tamanho=30),  # TRIM + MAIUSCULO + corta em 30
    }
    dados.update({c: linha[c] for c in COPIADOS})                     # demais campos sem tratamento
    return dados
