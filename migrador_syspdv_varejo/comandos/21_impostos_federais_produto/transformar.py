from app.ajudantes import inteiro


def transformar(linha):
    return {
        "procod": inteiro(linha["procod"], "PROCOD"),     # TRIM + Integer
        "impfedsim": linha["impfedsim"],                  # como no SysPDV (igual ao item Impostos Federais)
    }
