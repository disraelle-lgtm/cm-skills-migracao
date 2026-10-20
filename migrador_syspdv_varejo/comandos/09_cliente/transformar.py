"""
Regras do T-Cliente-Pessoa2 (pessoa) e do T-Cliente-PessoaCliente (pessoa_cliente).

O Pentaho divide os clientes em 3 caminhos:
  - SEM DOCUMENTO (CPF/CNPJ vazio)  -> pessoa nova; vai para a planilha Clientes_Sem_Documento.xls
  - FISICA  -> CPF com zeros a esquerda ate 11, e-mail minusculo, endereco MAIUSCULO
  - demais  -> CNPJ com zeros a esquerda ate 14, e-mail minusculo, endereco MAIUSCULO
Tambem aplica aqui as correcoes do item "Ajustes finais de Pessoas" que mexem nos mesmos
campos (bairro vazio, fantasia vazia, CPF com mais de 11 digitos vira JURIDICA...), para
que rodar de novo nao fique "atualizando" o que os ajustes ja corrigiram.
"""
from app.ajudantes import inteiro, so_digitos, texto

TIPO_PESSOA = {"F": "FISICA", "J": "JURIDICA", "E": "ESTRANGEIRO"}            # padrao FISICA
ESTADO_CIVIL = {"S": "SOLTEIRO", "O": "OUTROS", "D": "DIVORCIADO", "V": "VIUVO", "C": "CASADO"}  # padrao OUTROS
SEXO = {"M": "MASCULINO", "F": "FEMININO"}                                   # padrao MASCULINO
SITUACAO = {"N": "NAO", "S": "SIM"}                                          # padrao PENDENTE
TIPO_RESIDENCIA = {"O": "OUTRAS", "P": "PROPRIA", "F": "FINANCIADA", "D": "DE_PARENTE", "A": "ALUGADA"}


def _corte(valor, tamanho):
    return None if valor is None else str(valor)[:tamanho]


def _telefone(valor):
    """Replace in string: tira ( ) - . do telefone."""
    if valor is None:
        return None
    t = str(valor)
    for c in "()-.":
        t = t.replace(c, "")
    return t or None


def _inteiro_ou_nulo(valor):
    t = texto(valor)
    return int(t) if t else None


def transformar(linha):
    documento = so_digitos(linha["clicpfcgc"])
    tipo = TIPO_PESSOA.get(texto(linha["clipfpj"]) or "", "FISICA")
    email = texto(linha["cliemail"])
    endereco = _corte(linha["cliend"], 100)
    aviso = None

    if documento is None:                       # caminho "PESSOA Sem CNPJ/CPF"
        aviso = "cliente sem CPF/CNPJ (no Pentaho ia para Clientes_Sem_Documento.xls)"
    else:                                       # caminhos FISICA e JURIDICA
        documento = documento.rjust(11 if tipo == "FISICA" else 14, "0")
        email = email.lower() if email else None
        endereco = texto(endereco)
        endereco = endereco.upper() if endereco else None
        # Ajustes finais de Pessoas ("VF - Corrige Tipo Documento"): FISICA com mais de 11 digitos
        if tipo == "FISICA" and len(documento) > 11:
            tipo, documento = "JURIDICA", documento.rjust(14, "0")

    numero = texto(_corte(linha["clinum"], 6))
    nome = _corte(linha["clides"], 100)
    fantasia = _corte(linha["clifan"], 100)
    observacao = linha["cliobs"]
    tipo_residencia = texto(linha["clitipres"])                    # TRIM + Null if ' '
    contato = linha["clicon"] if linha["clicon"] not in ("", None) else None   # Null if ''

    dados = {
        "cli_codigo": inteiro(linha["clicod"], "CLICOD"),
        # ---------------- pessoa (T-Cliente-Pessoa2)
        "pes_tipo": tipo,
        "pes_num_documento": documento,
        "pes_num_identificacao": so_digitos(linha["clirgcgf"]) or "ISENTO",
        "pes_insc_municipal": linha["cliinscmun"],
        "pes_nome": nome,
        "pes_cep": (so_digitos(linha["clicep"]) or "")[:10] or None,
        "pes_uf": texto(_corte(linha["cliest"], 2)),
        "pes_pais": int(texto(linha["clipais"]) or "1058"),
        "pes_logradouro": endereco,
        "pes_numero": "SN" if numero in (None, "0") else numero,  # Value Mapper: 0 ou vazio = SN
        "pes_complemento": _corte(linha["clicmp"], 40),
        "mcp_codigo_ibge": _inteiro_ou_nulo(linha["clicodigoibge"]),
        "pes_descricao_cidade": linha["clicid"],
        "pes_telefone1": (_telefone(linha["clitel"]) or "")[:11] or "99999999999",
        "pes_telefone2": _telefone(linha["clitel2"]),
        "pes_fax": linha["clifax"],
        "pes_email": email or "modelo@modelo.com.br",
        "pes_fantasia": fantasia if texto(fantasia) else nome,      # Ajustes finais: fantasia vazia = nome
        "pes_rg_expedidor": linha["clirgexp"],
        "pes_bairro": _corte(linha["clibai"], 60) if texto(linha["clibai"]) else "SEM DESCRICAO",  # Ajustes finais
        "pes_data_cadastro": linha["clidtcad"],
        # ---------------- pessoa_cliente (T-Cliente-PessoaCliente)
        "cli_comp_data_nascimento": linha["clidtnas"],
        "cli_comp_estado_civil": ESTADO_CIVIL.get(texto(linha["cliestciv"]) or "", "OUTROS"),
        "cli_comp_sexo": SEXO.get(texto(linha["clisex"]) or "", "MASCULINO"),
        "cli_comp_orgao_publico": texto(linha["cliorgpub"]) or "N",       # Ajustes finais: nulo = N
        "cli_comp_retem_iss": texto(linha["cliretemiss"]) or "N",         # Ajustes finais: nulo = N
        "cli_comp_atividade": linha["clicae"],
        "cli_comp_naturalidade": linha["clinat"],
        "cli_comp_observacao": None if observacao is None else str(observacao)[:60],
        "cli_comp_tipo_residencia": TIPO_RESIDENCIA.get(tipo_residencia, tipo_residencia) if tipo_residencia else None,
        "cli_comp_tempo_residencia": linha["clitmpres"],
        "cli_comp_temp_trab_emp_atual": linha["cliemptmp"],
        "cli_comp_comprovante_renda": linha["clicprrda"],
        "cli_comp_situacao_aprovacao": SITUACAO.get(texto(linha["clisitapr"]) or "", "PENDENTE"),
        "cli_versao": 0,
        "stacod": _inteiro_ou_nulo(linha["stacod"]),
        "ramcod": int((linha["ramcod"] or "").rstrip() or "0"),         # TRIM a direita, nulo = 0
        "cli_comp_tipo_preco": _inteiro_ou_nulo(linha["clitipprc"]),
        "cli_comp_pessoa_contato": contato,
    }
    if aviso:
        dados["_aviso"] = aviso
    return dados
