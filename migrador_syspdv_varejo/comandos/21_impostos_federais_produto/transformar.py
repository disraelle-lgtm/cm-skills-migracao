from app.ajudantes import inteiro


def transformar(linha):
    return {
        "procod": inteiro(linha["procod"], "PROCOD"),     # TRIM + Integer
        "impfedsim": linha["impfedsim"],                  # como no SysPDV (igual ao item Impostos Federais)
        "qtd_mesmo_tipo": 1,     # 1 imposto de cada tipo por produto (comparado com o existe.sql: duplicidade -> atualiza)
    }
