"""
Formulario de validacao da migracao (modelo do usuario: app/formulario_modelo/validacao_migracao.docx).

Gerado no FIM de toda migracao (inicial ou virada): preenche o modelo com "SysPDV: N | VarejoFacil: M" para cada
tabela da secao "Dados Migrados", as Informacoes Complementares e as listas de Situacao Fiscal e Impostos Federais.
As contagens do SysPDV usam as MESMAS regras da migracao (codigo zerado, sem descricao, fora de linha conforme a
opcao, fornecedor sem CNPJ...) e SQL comum a Firebird e SQL Server. Uma contagem que falhar vira "—" (o formulario
e gerado mesmo assim). Nada e gravado nos bancos.
"""
from __future__ import annotations

import copy
import time
from pathlib import Path

MODELO = Path(__file__).parent / "formulario_modelo" / "validacao_migracao.docx"
Z = lambda col: f"REPLACE({col}, '0', '') <> ''"          # codigo zerado (00, 000...) nao conta


MOV_DATA = None          # data da opcao "Somente produtos com movimentacao desde" (definida em gerar)


def _filtro_produto(fora_de_linha: bool, a: str = "p") -> str:
    fl = "1 = 1" if fora_de_linha else f"COALESCE({a}.PROFORLIN, 'N') = 'N'"
    base = f"{a}.PRODES IS NOT NULL AND {Z(a + '.PROCOD')} AND {fl}"
    if MOV_DATA:
        from app.motor import filtro_movimentacao
        base += " AND " + filtro_movimentacao(a).replace(":param_mov_data", f"CAST('{MOV_DATA.isoformat()}' AS DATE)")
    return base


def _linhas(fora_de_linha: bool) -> list[tuple[str, str | None, str | None]]:
    """(rotulo do formulario, contagem no SysPDV, contagem no VarejoFacil)."""
    P = _filtro_produto(fora_de_linha)
    PI = f"SELECT p.PROCOD FROM PRODUTO p WHERE {P}"
    matriz = "(SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)"
    est = lambda cond: (f"SELECT COUNT(*) FROM PRODUTO p JOIN ESTOQUE e ON e.PROCOD = p.PROCOD WHERE {P} AND e.ESTATUSDO {cond}",
                        f"SELECT count(*) FROM estoque_resumo WHERE loc_codigo = 1 AND loj_codigo = {matriz} AND res_saldo {cond}")
    return [
        ("Seção", f"SELECT COUNT(*) FROM SECAO WHERE {Z('SECCOD')}", "SELECT count(*) FROM secao"),
        # grupo/subgrupo "orfao" (secao ou grupo que nao existe no SysPDV) nao e migrado: nao conta na origem
        ("Grupo", f"SELECT COUNT(*) FROM GRUPO WHERE SECCOD IN (SELECT SECCOD FROM SECAO) AND {Z('SECCOD')} AND {Z('GRPCOD')}",
         "SELECT count(*) FROM grupo_produto"),
        ("Subgrupo", "SELECT COUNT(*) FROM SUBGRUPO b INNER JOIN SECAO s ON (s.SECCOD = b.SECCOD) "
                     "INNER JOIN GRUPO g ON (g.SECCOD = b.SECCOD AND g.GRPCOD = b.GRPCOD) "
                     f"WHERE {Z('b.SECCOD')} AND {Z('b.GRPCOD')} AND {Z('b.SGRCOD')}",
         "SELECT count(*) FROM subgrupo_produto"),
        ("Impostos Federais", "SELECT COUNT(*) FROM IMPOSTOS_FEDERAIS WHERE (IMPFEDST IS NULL OR IMPFEDSTSAI IS NULL OR IMPFEDST <> IMPFEDSTSAI)", "SELECT count(*) FROM impostos_federais"),
        ("Local Estoque", "SELECT COUNT(*) FROM LOCAL WHERE LOCSTATUS = 'A'", "SELECT count(*) FROM local_estoque"),
        ("Loja", "SELECT COUNT(*) FROM PROPRIO", "SELECT count(*) FROM pessoa_loja"),
        ("Funcionário", f"SELECT COUNT(*) FROM FUNCIONARIO WHERE FUNINATIVO = 'N' AND {Z('FUNCOD')}",
         "SELECT count(*) FROM pessoa_funcionario WHERE fun_codigo < 1000000000"),
        ("Cliente", f"SELECT COUNT(*) FROM CLIENTE WHERE {Z('CLICOD')} AND CLIDES IS NOT NULL", "SELECT count(*) FROM pessoa_cliente"),
        ("Limite de Crédito", f"SELECT COUNT(*) FROM CLIENTE WHERE {Z('CLICOD')} AND CLIDES IS NOT NULL AND CLILIMCRE > 0",
         "SELECT count(*) FROM limite_de_credito"),
        ("Fornecedor", f"SELECT COUNT(*) FROM FORNECEDOR WHERE FORCGC IS NOT NULL AND FORCGC <> '' AND {Z('FORCOD')}",
         "SELECT count(*) FROM pessoa_fornecedor"),
        ("Agente Financeiro", f"SELECT COUNT(*) FROM AGENTE WHERE {Z('AGECOD')}", "SELECT count(*) FROM pessoa_agente_financeiro"),
        ("Produto", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P}", "SELECT count(*) FROM produto"),
        # o VarejoFacil aceita 1 imposto de cada tipo por produto: conta (produto, tipo) distintos, como a migracao
        ("Imp. Federais Produtos", "SELECT COUNT(*) FROM (SELECT DISTINCT i.PROCOD, f.IMPFEDTIP FROM IMPOSTOS_FEDERAIS_PRODUTO i "
                                   f"JOIN IMPOSTOS_FEDERAIS f ON f.IMPFEDSIM = i.IMPFEDSIM WHERE i.PROCOD IN ({PI})) pares",
         "SELECT count(*) FROM impostos_federais_produto"),
        ("Produto Com Auxiliar", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND EXISTS (SELECT 1 FROM PRODUTOAUX a WHERE a.PROCOD = p.PROCOD)",
         "SELECT count(*) FROM produto p WHERE EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = p.procod)"),
        ("Produto Sem Auxiliar", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND NOT EXISTS (SELECT 1 FROM PRODUTOAUX a WHERE a.PROCOD = p.PROCOD)",
         "SELECT count(*) FROM produto p WHERE NOT EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = p.procod)"),
        ("Produto Fornecedor", "SELECT COUNT(*) FROM PRODUTO_FORNECEDOR pf JOIN FORNECEDOR f ON f.FORCOD = pf.FORCOD "
                               f"WHERE {Z('pf.FORCOD')} AND f.FORCGC IS NOT NULL AND f.FORCGC <> '' AND pf.PROCOD IN ({PI})",
         "SELECT count(*) FROM produto_fornecedor"),
        ("Preço Maior Que Zero", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND p.PROPRCVDAVAR > 0 AND p.PROPRCVDAVAR < 7890000000000",
         f"SELECT count(*) FROM preco WHERE lojcod = {matriz} AND prcvdavar > 0"),
        ("Preço Zero", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND (p.PROPRCVDAVAR IS NULL OR p.PROPRCVDAVAR <= 0 OR p.PROPRCVDAVAR >= 7890000000000)",
         f"SELECT count(*) FROM preco WHERE lojcod = {matriz} AND COALESCE(prcvdavar, 0) <= 0"),
        ("Tributação/Situação Fiscal", f"SELECT COUNT(DISTINCT p.TRBID) FROM PRODUTO p WHERE p.TRBID IS NOT NULL AND {P}",
         "SELECT count(*) FROM situacao_fiscal"),
        ("Produto Familia", "SELECT COUNT(*) FROM SIMILARES WHERE SIMILARESDES IS NOT NULL", "SELECT count(*) FROM familia_produto"),
        # como a migracao (e o Pentaho): produto marcado como composicao/kit SO conta se tiver os registros na
        # COMPOSTO / COMPONENTE (produto marcado sem componentes nao e migrado). No VarejoFacil os dois ficam na
        # composicao: composicao com comp_tipo vazio, kit com comp_tipo (PRECO/FATOR).
        ("Produto Composição", f"SELECT COUNT(*) FROM PRODUTO p WHERE p.PROCOMP = 'S' AND {P} "
                               "AND EXISTS (SELECT 1 FROM COMPOSTO c WHERE c.PROCOD = p.PROCOD)",
         "SELECT count(DISTINCT comp_procod) FROM composicao WHERE comp_tipo IS NULL"),
        ("Produto Kit", f"SELECT COUNT(*) FROM PRODUTO p WHERE p.PROCOMP = 'K' AND {P} "
                        "AND EXISTS (SELECT 1 FROM COMPONENTE c WHERE c.PROCOD = p.PROCOD)",
         "SELECT count(DISTINCT comp_procod) FROM composicao WHERE comp_tipo IS NOT NULL"),
        ("Encarte", "SELECT COUNT(*) FROM ENCARTE WHERE ENCSTATUS IN ('A', 'P')", "SELECT count(*) FROM encarte"),
        ("Estoque Positivo", *est("> 0")),
        ("Estoque Negativo", *est("< 0")),
        ("Estoque Zero", *est("= 0")),
        ("Contas Receber", "SELECT COUNT(*) FROM CONTARECEBER cr JOIN CLIENTE cl ON cr.CLICOD = cl.CLICOD "
                           f"WHERE cr.CTRTIPPAG IN ('A', 'P') AND {Z('cl.CLICOD')} AND cl.CLIDES IS NOT NULL",
         "SELECT count(*) FROM conta_a_receber"),
        ("Contas Pagar", "SELECT COUNT(*) FROM CONTAPAGAR ct JOIN FORNECEDOR f ON ct.FORCOD = f.FORCOD "
                         "WHERE ct.CTPDATPGT IS NULL AND ct.CTPTIPPAG = 'A' AND f.FORCGC IS NOT NULL AND ct.CTPLOGEXCLUSAO = 'N'",
         "SELECT count(*) FROM conta_a_pagar"),
    ]


def _contar(con, sql, pg: bool):
    if not sql:
        return None
    try:
        if pg:
            with con.transaction():
                return int(con.execute(sql).fetchone()[0])
        cur = con.cursor()
        cur.execute(sql)
        n = cur.fetchone()[0]
        cur.close()
        return int(n)
    except Exception:
        if not pg:
            try:
                con.rollback()
            except Exception:
                pass
        return None


def _texto(origem, destino) -> str:
    o = "—" if origem is None else f"{origem:,}".replace(",", ".")
    d = "—" if destino is None else f"{destino:,}".replace(",", ".")
    s = f"SysPDV: {o}  |  VarejoFácil: {d}"
    if origem is not None and destino is not None and origem != destino:
        dif = destino - origem
        s += f"  (diferença: {'+' if dif > 0 else ''}{dif:,})".replace(",", ".")
    return s


def _escrever(celula, texto: str, negrito: bool = False, extra: str = "", centro: bool = False):
    """Escreve na celula (letra 9 como o modelo). 'extra' vai em vermelho logo depois (ex.: a diferenca)."""
    from docx.shared import Pt, RGBColor
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    p = celula.paragraphs[0]
    for r in list(p.runs):
        r._element.getparent().remove(r._element)
    if centro:
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(texto)
    run.bold = negrito
    run.font.size = Pt(9)
    if extra:
        r2 = p.add_run(extra)
        r2.font.size = Pt(8)
        r2.bold = True
        r2.font.color.rgb = RGBColor(0xC0, 0x1C, 0x1C)


def _tres_colunas(tabela, primeira: str = "Tabelas"):
    """Dados Migrados: a coluna de valor vira 'Origem SysPDV' + 'Destino VarejoFacil' (mesma largura total),
    o titulo verde passa a ocupar as 3 colunas e entra a linha de cabecalho 'Tabelas | Origem | Destino'."""
    from docx.oxml.ns import qn
    from docx.oxml import OxmlElement
    from docx.table import _Row
    tbl = tabela._tbl
    grid = tbl.find(qn("w:tblGrid"))
    cols = grid.findall(qn("w:gridCol"))
    largura = int(cols[-1].get(qn("w:w")))
    a, b = largura // 2, largura - largura // 2
    cols[-1].set(qn("w:w"), str(a))
    nova = copy.deepcopy(cols[-1]); nova.set(qn("w:w"), str(b)); grid.append(nova)
    for tr in tbl.findall(qn("w:tr")):
        tcs = tr.findall(qn("w:tc"))
        if len(tcs) == 1:                                  # titulo verde: passa a ocupar as 3 colunas
            pr = tcs[0].get_or_add_tcPr()
            gs = pr.find(qn("w:gridSpan"))
            if gs is None:
                gs = OxmlElement("w:gridSpan"); pr.append(gs)
            gs.set(qn("w:val"), "3")
            continue
        ultimo = tcs[-1]
        ultimo.get_or_add_tcPr().get_or_add_tcW().set(qn("w:w"), str(a))
        novo = copy.deepcopy(ultimo)
        # a copia herda a borda grossa da ESQUERDA (a que separa rotulo e valor): entre Origem e Destino fica a normal
        bordas = novo.get_or_add_tcPr().find(qn("w:tcBorders"))
        if bordas is not None:
            for lado in ("w:left", "w:start"):
                b_ = bordas.find(qn(lado))
                if b_ is not None:
                    bordas.remove(b_)
        bordas = ultimo.get_or_add_tcPr().find(qn("w:tcBorders"))
        if bordas is not None:
            for lado in ("w:right", "w:end"):
                b_ = bordas.find(qn(lado))
                if b_ is not None:
                    bordas.remove(b_)
        novo.get_or_add_tcPr().get_or_add_tcW().set(qn("w:w"), str(b))
        ultimo.addnext(novo)
    linhas = tbl.findall(qn("w:tr"))
    cab = copy.deepcopy(linhas[1])                         # copia de uma linha de dados (mesmas bordas)
    linhas[0].addnext(cab)
    linha = _Row(cab, tabela)
    _escrever(linha.cells[0], primeira, negrito=True)
    _escrever(linha.cells[1], "Origem SysPDV", negrito=True, centro=True)
    _escrever(linha.cells[2], "Destino VarejoFácil", negrito=True, centro=True)


def _num(n) -> str:
    return "—" if n is None else f"{n:,}".replace(",", ".")


def _preencher_dados(tabela, valores: dict[str, tuple]):
    """Dados Migrados (3 colunas): origem e destino; diferenca em vermelho no destino quando nao batem."""
    alvo = {k.lower(): v for k, v in valores.items()}
    for linha in tabela.rows:
        cel = linha.cells
        if len(cel) < 3 or cel[0]._tc is cel[-1]._tc:
            continue
        r = _rotulo(cel[0])
        if r in alvo:
            o, d = alvo[r]
            dif = ""
            if o is not None and d is not None and o != d:
                dif = f"  (dif. {'+' if d - o > 0 else ''}{_num(d - o)})"
            _escrever(cel[1], _num(o), centro=True)
            _escrever(cel[2], _num(d), extra=dif, centro=True)


def _rotulo(celula) -> str:
    return " ".join(celula.text.split()).strip().lower()


def _preencher_por_rotulo(tabela, valores: dict[str, str]):
    alvo = {k.lower(): v for k, v in valores.items()}
    for linha in tabela.rows:
        if len(linha.cells) < 2:
            continue
        r = _rotulo(linha.cells[0])
        if r in alvo:
            if linha.cells[0]._tc is linha.cells[-1]._tc:
                # linha de TITULO (celula unica, ex.: "Migração" em verde): acrescenta o texto mantendo a formatacao
                runs = linha.cells[0].paragraphs[0].runs
                if runs:
                    runs[-1].text = runs[-1].text.rstrip() + " " + alvo[r]
            else:
                _escrever(linha.cells[-1], alvo[r])


def _lista(tabela, itens: list[tuple[str, str]]):
    """Tabelas de Situacao Fiscal / Impostos Federais: titulo + cabecalho ('X Migrada | Quantidade'). Cada item vira
    uma linha nova copiada do cabecalho (mesmas bordas/larguras), com o texto sem negrito."""
    from docx.table import _Row
    modelo = tabela.rows[-1]._tr
    vazia = all(not c.text.strip() for c in tabela.rows[-1].cells)
    for i, (nome, qtd) in enumerate(itens or [("nenhum(a) migrado(a)", "")]):
        if i == 0 and vazia:
            tr = modelo
        else:
            tr = copy.deepcopy(modelo)
            tabela._tbl.append(tr)
        linha = _Row(tr, tabela)
        _escrever(linha.cells[0], nome)
        _escrever(linha.cells[-1], qtd)


def _bordas_pretas(doc):
    """Todas as tabelas com bordas PRETAS explicitas (linha simples 0,5 pt) em toda a grade. O modelo usa bordas de
    cor automatica definidas celula a celula, que somem ao salvar em PDF em alguns programas."""
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
    for tabela in doc.tables:
        tbl = tabela._tbl
        pr = tbl.tblPr
        antigo = pr.find(qn("w:tblBorders"))
        if antigo is not None:
            pr.remove(antigo)
        bordas = OxmlElement("w:tblBorders")
        for lado in ("top", "left", "bottom", "right", "insideH", "insideV"):
            b = OxmlElement(f"w:{lado}")
            b.set(qn("w:val"), "single"); b.set(qn("w:sz"), "4"); b.set(qn("w:space"), "0"); b.set(qn("w:color"), "000000")
            bordas.append(b)
        # ordem do esquema: tblBorders vem antes de shd/tblLayout/tblCellMar/tblLook
        depois = [qn(x) for x in ("w:shd", "w:tblLayout", "w:tblCellMar", "w:tblLook", "w:tblCaption", "w:tblDescription")]
        ref = next((e for e in pr if e.tag in depois), None)
        ref.addprevious(bordas) if ref is not None else pr.append(bordas)
        for tc in tbl.iter(qn("w:tc")):                 # bordas por celula anulariam as da tabela
            tcpr = tc.find(qn("w:tcPr"))
            if tcpr is not None and tcpr.find(qn("w:tcBorders")) is not None:
                tcpr.remove(tcpr.find(qn("w:tcBorders")))


def _so_linhas(tbl_xml, manter: set[str]):
    """Remove da tabela as linhas de dados cujo rotulo nao esta em 'manter' (o titulo verde fica)."""
    from docx.oxml.ns import qn
    for tr in tbl_xml.findall(qn("w:tr")):
        tcs = tr.findall(qn("w:tc"))
        if len(tcs) == 1:
            continue
        rotulo = " ".join("".join(tcs[0].itertext()).split()).strip().lower()
        if not any(rotulo.startswith(m) for m in manter):
            tbl_xml.remove(tr)


def nome_arquivo(con_pg, nome_cliente: str, banco: str) -> str:
    """'<Nome do Cliente> (<CNPJ>) - Validação de Migração.docx' (padrao da equipe). Nome vazio = razao social da
    loja matriz; CNPJ = documento da loja matriz no VarejoFacil. Tira os caracteres que o Windows nao aceita."""
    import re
    razao, cnpj = None, None
    try:
        with con_pg.transaction():
            r = con_pg.execute("SELECT p.pes_nome, p.pes_num_documento FROM pessoa_loja l JOIN pessoa p ON p.pes_codigo = l.pes_codigo "
                               "WHERE l.loj_matriz = 'S' ORDER BY l.loj_codigo LIMIT 1").fetchone()
            if r:
                razao, cnpj = r
    except Exception:
        pass
    nome = (nome_cliente or "").strip() or (razao or "").strip() or banco
    cnpj = re.sub(r"\D", "", cnpj or "")
    base = f"{nome} ({cnpj})" if cnpj else nome
    base = re.sub(r'[\\/:*?"<>|]+', " ", base)
    base = re.sub(r"\s+", " ", base).strip(" .")[:150] or "Cliente"
    return f"{base} - Validação de Migração.docx"


def gerar(con_origem, con_pg, origem_tipo: str, opcoes: dict, conjunto: str, pasta: Path, versao: str,
          banco: str, log=print, respostas: dict | None = None) -> str | None:
    """Gera o formulario preenchido em <pasta>/formulario_migracao_<banco>_<data>.docx (nome do arquivo)."""
    try:
        from docx import Document
    except ImportError:
        log("AVISO: formulário não gerado - falta a biblioteca python-docx (rode de novo o instalador)")
        return None
    if not MODELO.exists():
        log("AVISO: formulário não gerado - modelo app/formulario_modelo/validacao_migracao.docx não encontrado")
        return None
    fora = bool(opcoes.get("fora_de_linha", True))
    global MOV_DATA
    from app.motor import _data_movimentacao
    MOV_DATA = _data_movimentacao(opcoes)
    doc = Document(str(MODELO))
    tabs = doc.tables
    agora = time.strftime("%d/%m/%Y %H:%M")
    sistema = "SysPDV (SQL Server)" if origem_tipo == "sqlserver" else "SysPDV (Firebird)"

    # 1) dados da migracao
    resp = respostas or {}
    _preencher_por_rotulo(tabs[0], {"Nome Cliente": resp.get("Nome Cliente") or "",
                                    "Analista de Migração": resp.get("Analista de Migração") or ""})
    _preencher_por_rotulo(tabs[0], {"Migração": f"{'Virada' if conjunto == 'virada' else 'Inicial'} — {agora}",  # vira "Migração Inicial — data"
                                    "Sistema de Origem": sistema, "Sistema de Destino": f"VarejoFácil (banco {banco})",
                                    "Migrador Usado": f"migrador_syspdv_varejo {versao}"
                                                      + (f" — produtos com movimentação desde {MOV_DATA:%d/%m/%Y}" if MOV_DATA else "")})
    # 2) dados migrados: SysPDV x VarejoFacil
    valores = {}
    for rotulo, sql_o, sql_d in _linhas(fora):
        valores[rotulo] = (_contar(con_origem, sql_o, False), _contar(con_pg, sql_d, True))
    _tres_colunas(tabs[1])
    _preencher_dados(tabs[1], valores)

    # 3) informacoes complementares em DUAS tabelas:
    #    a) do banco: produtos em linha / fora de linha / balanca (Informacao | Origem SysPDV | Destino VarejoFacil)
    #    b) respostas do analista no menu Relatorios: mudou codigo de produto / de cliente (Sim / Nao)
    #    (Multi Loja e Juros e Multas sairam a pedido do usuario)
    if len(tabs) > 2:
        from docx.oxml import OxmlElement
        from docx.table import Table
        tab_a = tabs[2]
        copia_b = copy.deepcopy(tab_a._tbl)
        _so_linhas(tab_a._tbl, {"produtos em linha", "produtos fora de linha", "produtos de balan"})
        _tres_colunas(tab_a, "Informação")
        P = _filtro_produto(True)
        _preencher_dados(tab_a, {
            "Produtos em Linha": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND COALESCE(p.PROFORLIN, 'N') = 'N'", False),
                                  _contar(con_pg, "SELECT count(*) FROM produto WHERE COALESCE(proforlin, 'N') = 'N'", True)),
            "Produtos fora de Linha": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND p.PROFORLIN = 'S'", False),
                                       _contar(con_pg, "SELECT count(*) FROM produto WHERE proforlin = 'S'", True)),
            "Produtos de Balança": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND p.PROENVBAL = 'S'", False),
                                    _contar(con_pg, "SELECT count(*) FROM produto WHERE proenvbal = 'S'", True)),
        })
        _so_linhas(copia_b, {"mudou codigo produto", "mudou codigo cliente"})
        espaco = OxmlElement("w:p")
        tab_a._tbl.addnext(espaco)
        espaco.addnext(copia_b)
        tab_b = Table(copia_b, tab_a._parent)
        resp = respostas or {}
        _preencher_por_rotulo(tab_b, {"Mudou Codigo Produto": resp.get("Mudou Codigo Produto", "—"),
                                      "Mudou Codigo Cliente": resp.get("Mudou Codigo Cliente", "—")})

    # 4) situacao fiscal e impostos federais migrados, com a quantidade de produtos
    def consulta(sql):
        try:
            with con_pg.transaction():
                return [(str(a), f"{b:,}".replace(",", ".") + " produto(s)") for a, b in con_pg.execute(sql).fetchall()]
        except Exception:
            return []
    if len(tabs) > 3:
        _lista(tabs[3], consulta("SELECT sf.stf_codigo || ' - ' || COALESCE(sf.stf_descricao_completa, sf.stf_descricao_reduzida, ''), "
                                 "count(p.procod) FROM situacao_fiscal sf LEFT JOIN produto p ON p.stf_codigo = sf.stf_codigo "
                                 "GROUP BY sf.stf_codigo, sf.stf_descricao_completa, sf.stf_descricao_reduzida ORDER BY sf.stf_codigo"))
    if len(tabs) > 4:
        _lista(tabs[4], consulta("SELECT f.impfedsim || ' - ' || COALESCE(f.impfeddes, ''), count(i.procod) FROM impostos_federais f "
                                 "LEFT JOIN impostos_federais_produto i ON i.impfedsim = f.impfedsim "
                                 "GROUP BY f.impfedsim, f.impfeddes ORDER BY f.impfedsim"))
    _bordas_pretas(doc)
    nome = nome_arquivo(con_pg, resp.get("Nome Cliente") or "", banco)
    destino = Path(pasta) / time.strftime("formulario_%Y%m%d_%H%M%S")      # pasta por geracao: o nome se repete
    destino.mkdir(parents=True, exist_ok=True)
    doc.save(str(destino / nome))
    nome = f"{destino.name}/{nome}"
    log(f"Formulário de validação gerado: {nome}")
    return nome
