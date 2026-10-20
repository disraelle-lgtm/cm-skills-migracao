from app.ajudantes import inteiro, so_digitos, texto

ATIVO_NA_LOJA = {"N": "S", "S": "N"}   # PARSE-INATIVO: inativo N -> ativo S (padrao S)


def transformar(linha):
    inativo = texto(linha["funinativo"])
    return {
        "funcod": inteiro(linha["funcod"], "FUNCOD"),
        # --- T-Funcionario-Pessoa: TRIM, If null 'USUARIO', CPF so numeros, tipo FISICA
        "pes_nome": texto(linha["fundes"], vazio="USUARIO"),
        "pes_fantasia": texto(linha["funape"], vazio="USUARIO"),
        "pes_num_documento": so_digitos(linha["funcpf"]),
        # --- T-Funcionario-PessoaFuncionario: campos como vem do SysPDV
        "fun_cargo_syspdv": linha["funcar"],
        "fun_limite_desconto": linha["funlimdcn"],
        "fun_comissao1": linha["funcom"],
        "fun_comissao2": linha["funcom2"],
        "fun_comissao3": linha["funcom3"],
        "fun_tipo_preco_padrao": linha["funtprc"],
        "fun_comissao_por_metas": linha["funcommt"],
        "fun_inativo": linha["funinativo"],
        "fun_ace": linha["funace"],
        # --- T-Funcionario-Loja: a loja e a MATRIZ ja cadastrada no VarejoFacil (ver inserir.sql)
        "pfl_ativo": ATIVO_NA_LOJA.get(inativo, "S"),
        "loja_matriz_ok": True,   # comparado com o existe.sql: se o vinculo nao for a matriz, atualiza
    }
