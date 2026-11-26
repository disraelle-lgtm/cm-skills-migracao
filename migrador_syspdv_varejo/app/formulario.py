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
         "SELECT count(*) FROM limite_de_credito WHERE lcr_valor > 0"),   # a migracao grava limite (zerado) p/ todo cliente
        ("Fornecedor", f"SELECT COUNT(*) FROM FORNECEDOR WHERE FORCGC IS NOT NULL AND FORCGC <> '' AND {Z('FORCOD')}",
         "SELECT count(*) FROM pessoa_fornecedor"),
        ("Agente Financeiro", f"SELECT COUNT(*) FROM AGENTE WHERE {Z('AGECOD')}", "SELECT count(*) FROM pessoa_agente_financeiro"),
        ("Produto", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P}", "SELECT count(*) FROM produto"),
        # o VarejoFacil aceita 1 imposto de cada tipo por produto: conta (produto, tipo) distintos, como a migracao
        # a MESMA origem do Progresso (todos os impostos dos produtos migrados): o 2o imposto do mesmo tipo no mesmo
        # produto nao e migrado (o VarejoFacil aceita 1 de cada tipo) e aparece como divergencia explicada
        ("Imp. Federais Produtos", f"SELECT COUNT(*) FROM IMPOSTOS_FEDERAIS_PRODUTO i WHERE i.PROCOD IN ({PI})",
         "SELECT count(*) FROM impostos_federais_produto"),
        ("Produto Com Auxiliar", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND EXISTS (SELECT 1 FROM PRODUTOAUX a WHERE a.PROCOD = p.PROCOD)",
         "SELECT count(*) FROM produto p WHERE EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = p.procod)"),
        ("Produto Sem Auxiliar", f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND NOT EXISTS (SELECT 1 FROM PRODUTOAUX a WHERE a.PROCOD = p.PROCOD)",
         "SELECT count(*) FROM produto p WHERE NOT EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = p.procod)"),
        ("Produto Fornecedor", "SELECT COUNT(*) FROM PRODUTO_FORNECEDOR pf JOIN FORNECEDOR f ON f.FORCOD = pf.FORCOD "
                               f"WHERE {Z('pf.FORCOD')} AND f.FORCGC IS NOT NULL AND f.FORCGC <> '' AND pf.PROCOD IN ({PI}) "
                               # como a migracao: sem a referencia do produto no fornecedor o vinculo nao e migrado
                               "AND pf.PRFREFFOR NOT IN ('00000000000000', '') AND pf.PROCOD NOT LIKE '% %'",
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
    # titulo + cabecalho "Tabelas | Origem | Destino" se repetem no topo de cada pagina (a tabela quebra de pagina)
    for tr in tbl.findall(qn("w:tr"))[:2]:
        trpr = tr.find(qn("w:trPr"))
        if trpr is None:
            trpr = OxmlElement("w:trPr"); tr.insert(0, trpr)
        if trpr.find(qn("w:tblHeader")) is None:
            trpr.append(OxmlElement("w:tblHeader"))


def _num(n) -> str:
    return "—" if n is None else f"{n:,}".replace(",", ".")


def _preencher_dados(tabela, valores: dict[str, tuple]):
    """Dados Migrados (3 colunas): origem e destino; diferenca em vermelho no destino quando nao batem."""
    alvo = {_norm(k): v for k, v in valores.items()}
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


def _norm(texto: str) -> str:
    """Texto para comparar rotulos/titulos: sem acento, minusculo, espacos simples."""
    import unicodedata
    t = unicodedata.normalize("NFKD", " ".join(str(texto).split()).strip().lower())
    return "".join(c for c in t if not unicodedata.combining(c))


def _rotulo(celula) -> str:
    return _norm(celula.text)


def _achar(doc, titulo: str):
    """A tabela cujo TITULO (texto da primeira linha) comeca com 'titulo' - o gerador nao depende da posicao das
    tabelas no modelo (o modelo de 2026.11 tem a caixa de Observacoes e o quadro-resumo antes da Migracao)."""
    alvo = _norm(titulo)
    for t in doc.tables:
        if t.rows and _norm(t.rows[0].cells[0].text).startswith(alvo):
            return t
    return None


def _resumo(tabela, valores: dict[str, tuple]):
    """Quadro-resumo do modelo novo: cartoes TABELAS CONFERIDAS / SEM DIVERGENCIA / COM DIVERGENCIA (o numero
    substitui o '—' do modelo, mantendo a formatacao do cartao)."""
    comparadas = [(o, d) for o, d in valores.values() if o is not None and d is not None]
    numeros = {"tabelas conferidas": len(comparadas), "sem divergencia": sum(1 for o, d in comparadas if o == d),
               "com divergencia": sum(1 for o, d in comparadas if o != d)}
    vistos = set()
    for celula in tabela.rows[0].cells:
        if id(celula._tc) in vistos or len(celula.paragraphs) < 2:
            continue
        vistos.add(id(celula._tc))
        chave = _norm(celula.paragraphs[0].text)
        if chave in numeros:
            runs = celula.paragraphs[1].runs
            if runs:
                runs[0].text = str(numeros[chave])
                for r in runs[1:]:
                    r.text = ""
    return numeros


def _preencher_por_rotulo(tabela, valores: dict[str, str]):
    alvo = {_norm(k): v for k, v in valores.items()}
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
            _linha_comum(tr)
        linha = _Row(tr, tabela)
        _escrever(linha.cells[0], nome)
        _escrever(linha.cells[-1], qtd)


# etapa da migracao (ultimo pedaco do id, sem o numero) -> linha do formulario
ETAPA_LINHA = {"secao": "Seção", "grupo": "Grupo", "subgrupo": "Subgrupo", "impostos_federais": "Impostos Federais",
               "pessoa_loja": "Loja", "funcionario": "Funcionário", "cliente": "Cliente", "limite_credito": "Limite de Crédito",
               "fornecedor": "Fornecedor", "agente_financeiro": "Agente Financeiro", "produto": "Produto",
               "impostos_federais_produto": "Imp. Federais Produtos", "produto_auxiliar": "Produto Com Auxiliar",
               "produto_fornecedor": "Produto Fornecedor", "preco": "Preço Maior Que Zero", "produto_familia": "Produto Familia",
               "composicao": "Produto Composição", "kit": "Produto Kit", "encarte": "Encarte", "saldo_positivo": "Estoque Positivo",
               "saldo_negativo": "Estoque Negativo", "conta_a_receber": "Contas Receber", "conta_a_pagar": "Contas Pagar",
               "situacao_fiscal": "Tributação/Situação Fiscal"}


def motivos_da_migracao(pasta_relatorios: Path, banco: str, loja: int | None) -> dict[str, dict]:
    """Os motivos que o Progresso mostrou, tirados dos relatorios gravados por cada migracao deste banco/loja
    (execucao.json): para cada etapa vale a execucao MAIS RECENTE que a rodou. Devolve, por linha do formulario,
    {"etapa": nome, "pulado": {motivo: [chaves]}, "erro": {...}, "nao_migrado": {...}}."""
    import csv, json, re
    por_etapa: dict[str, Path] = {}
    for pasta in sorted(p for p in Path(pasta_relatorios).glob("2*") if p.is_dir()):     # nomes por data: o ultimo vence
        try:
            meta = json.loads((pasta / "execucao.json").read_text(encoding="utf-8"))
        except Exception:
            continue
        if meta.get("simulacao") or meta.get("banco") != banco or (meta.get("loja_destino") or None) != (loja or None):
            continue
        for arq in pasta.glob("*.csv"):
            if not arq.stem.endswith(("_erros", "_nao_migrados")):
                por_etapa[arq.stem] = pasta
    resultado: dict[str, dict] = {}
    for etapa, pasta in por_etapa.items():
        chave = re.sub(r"^\d+[a-z]?_", "", etapa.split("__")[-1])
        linha = ETAPA_LINHA.get(chave)
        if not linha:
            continue
        info = resultado.setdefault(linha, {"pulado": {}, "erro": {}, "nao_migrado": {}})
        try:
            with (pasta / f"{etapa}.csv").open(encoding="utf-8-sig") as fh:
                for r in csv.DictReader(fh, delimiter=";"):
                    st = (r.get("status") or "").strip()
                    if st in ("pulado", "erro"):
                        info[st].setdefault((r.get("mensagem") or "").strip() or "sem motivo", []).append((r.get("chave") or "").strip())
            nm = pasta / f"{etapa}_nao_migrados.csv"
            if nm.exists():
                with nm.open(encoding="utf-8-sig") as fh:
                    for r in csv.DictReader(fh, delimiter=";"):
                        r = {k.lower(): v for k, v in r.items() if k}
                        info["nao_migrado"].setdefault((r.get("motivo") or "").strip() or "sem motivo", []).append((r.get("registro") or "").strip())
        except Exception:
            continue
    return {k: v for k, v in resultado.items() if any(v.values())}


def _texto_motivos(info: dict, limite: int = 5) -> str:
    """'3 pulado(s): motivo (1001, 1002, 1003); 2 não migrado(s): ...'"""
    nomes = {"pulado": "pulado(s)", "nao_migrado": "não migrado(s)", "erro": "com erro"}
    partes = []
    for tipo in ("pulado", "nao_migrado", "erro"):
        for motivo, chaves in sorted(info.get(tipo, {}).items(), key=lambda x: -len(x[1])):
            ex = ", ".join(c.split("|")[0].lstrip("0") or c for c in chaves[:limite]) + (" …" if len(chaves) > limite else "")
            partes.append(f"{len(chaves)} {nomes[tipo]}: {motivo} ({ex})")
    return "; ".join(partes)


def _motivo(rotulo: str, o: int, d: int, con_origem, con_pg, loja: int | None) -> tuple[bool, str]:
    """(esperada, texto) para uma divergencia origem x destino. esperada = explicada pelas regras da migracao."""
    dif = d - o
    def n(con, sql, pg):
        v = _contar(con, sql, pg)
        return v if isinstance(v, int) else None
    Z = lambda c: f"REPLACE({c}, '0', '') <> ''"
    lojas = n(con_pg, "SELECT count(*) FROM pessoa_loja", True) or 1
    r = _norm(rotulo)
    if r == "loja" and dif > 0:
        return True, (f"o VarejoFácil tem {d} lojas cadastradas (lojas criadas na implantação ou migradas pela Migração Multi "
                      "Loja); o banco do SysPDV tem só a própria loja.")
    if r == "cliente" and dif < 0:
        partes = []
        rep = n(con_origem, f"SELECT COUNT(*) - COUNT(DISTINCT CLICPFCGC) FROM CLIENTE WHERE {Z('CLICOD')} AND CLIDES IS NOT NULL "
                            "AND CLICPFCGC IS NOT NULL AND CLICPFCGC <> ''", False)
        if rep:
            partes.append(f"{rep} cliente(s) com o mesmo CPF/CNPJ de outro cliente: o VarejoFácil aceita um cliente por pessoa "
                          "(ficam como \"pulado\" no cartão do Cliente)")
        if loja:
            sem = n(con_origem, f"SELECT COUNT(*) FROM CLIENTE WHERE {Z('CLICOD')} AND CLIDES IS NOT NULL "
                                "AND (CLICPFCGC IS NULL OR CLICPFCGC = '')", False)
            if sem:
                partes.append(f"{sem} cliente(s) sem CPF/CNPJ não são migrados na loja adicional")
        if partes:
            return sum([rep or 0, (sem if loja else 0) or 0]) >= -dif, "; ".join(partes) + "."
    if r in ("cliente", "fornecedor", "funcionario", "secao", "grupo", "subgrupo", "produto") and dif > 0 and not loja:
        return True, (f"o VarejoFácil já tinha {dif} cadastro(s) a mais (de outras lojas — Migração Multi Loja — ou criados "
                      "no próprio VarejoFácil).")
    if r == "imp. federais produtos" and dif < 0:
        PI = ("SELECT p.PROCOD FROM PRODUTO p WHERE p.PRODES IS NOT NULL AND REPLACE(p.PROCOD, '0', '') <> ''")
        rep = n(con_origem, f"SELECT COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT i.PROCOD, f.IMPFEDTIP FROM IMPOSTOS_FEDERAIS_PRODUTO i "
                            f"JOIN IMPOSTOS_FEDERAIS f ON f.IMPFEDSIM = i.IMPFEDSIM WHERE i.PROCOD IN ({PI})) x) "
                            f"FROM IMPOSTOS_FEDERAIS_PRODUTO i WHERE i.PROCOD IN ({PI})", False)
        if rep:
            return rep >= -dif, (f"{rep} imposto(s) federal(is) a mais do MESMO tipo no mesmo produto (ex.: dois PIS): o "
                                 "VarejoFácil aceita 1 de cada tipo por produto e fica o de menor código.")
    if r == "produto fornecedor" and dif < 0:
        rem = n(con_pg, "SELECT count(*) FROM migracao_auditoria.produto_fornecedor_removido", True)
        if rem:
            return rem >= -dif, (f"{rem} vínculo(s) produto × fornecedor removido(s): a mesma referência do fornecedor em "
                                 "produtos diferentes (não há como saber qual é o certo; cópia em "
                                 "migracao_auditoria.produto_fornecedor_removido).")
    if r == "agente financeiro" and dif > 0:
        return True, f"o VarejoFácil já vem com {dif} agente(s) financeiro(s) padrão."
    if r == "produto" and dif < 0 and loja:
        return True, "produtos sem código de barras não são migrados na loja adicional (regra da Migração Multi Loja)."
    if r == "estoque zero" and dif > 0:
        return True, ("todo produto sem registro de estoque no SysPDV recebe o saldo zero (todo produto precisa ter saldo em "
                      "todas as lojas para o extrato e a posição de estoque).")
    if r in ("preco maior que zero", "preco zero") and dif > 0 and lojas > 1:
        return True, "preços copiados de outras lojas (espelhamento de preço da Migração Multi Loja)."
    if dif > 0 and lojas > 1 and not loja:
        return True, (f"o VarejoFácil tem {lojas} lojas: a contagem do destino é do VarejoFácil inteiro e inclui os dados das "
                      "outras lojas. Para comparar só uma loja adicional, gere o formulário dela com o campo \"Loja adicional\".")
    return False, ("diferença não explicada pelas regras do migrador: confira o cartão do item no Progresso (erros, pulados e "
                   "não migrados) e o relatório linha a linha.")


def _secao_divergencias(doc, modelo_tbl, itens: list[tuple[str, int, int, bool, str]], titulo: str = "Divergências explicadas",
                        vazio: tuple[str, str] = ("Nenhuma divergência", "origem e destino iguais em todas as tabelas conferidas.")):
    """Secao "Divergências explicadas" no fim do formulario, copiando o visual de uma tabela de 2 colunas do modelo
    (titulo + linhas rotulo | valor). Cada divergencia: tabela (origem → destino) | ✓ Esperada / ⚠ Conferir + motivo."""
    from docx.oxml import OxmlElement
    from docx.oxml.ns import qn
    from docx.table import Table, _Row
    from docx.shared import Pt, RGBColor
    novo = copy.deepcopy(modelo_tbl)
    linhas = novo.findall(qn("w:tr"))
    tr_titulo, modelo = linhas[0], linhas[1]
    for tr in linhas[1:]:
        novo.remove(tr)
    tabela = Table(novo, None)
    runs = _Row(tr_titulo, tabela).cells[0].paragraphs[0].runs
    if runs:
        runs[0].text = titulo
        for r_ in runs[1:]:
            r_.text = ""
    for rotulo, o, d, esperada, texto in (itens or [(vazio[0], None, None, None, vazio[1])]):
        tr = copy.deepcopy(modelo); novo.append(tr); _linha_comum(tr)
        linha = _Row(tr, tabela)
        _escrever(linha.cells[0], rotulo + (f"  ({_num(o)} → {_num(d)})" if o is not None else ""), negrito=True)
        cel = linha.cells[-1]
        _escrever(cel, "")
        p = cel.paragraphs[0]
        for r_ in list(p.runs):
            r_._element.getparent().remove(r_._element)
        if esperada is not None:
            rr = p.add_run("✓ Esperada — " if esperada else "⚠ Conferir — ")
            rr.bold = True; rr.font.size = Pt(9)
            rr.font.color.rgb = RGBColor(0x1B, 0x7A, 0x34) if esperada else RGBColor(0xC0, 0x1C, 0x1C)
        rt = p.add_run(texto); rt.font.size = Pt(9)
    ultimo = doc.tables[-1]._tbl
    espaco = OxmlElement("w:p")
    ultimo.addnext(espaco)
    espaco.addnext(novo)


def _linha_comum(tr):
    """Linha copiada do cabecalho vira linha comum: sem fundo (shd) e sem 'repetir como cabecalho' (tblHeader)."""
    from docx.oxml.ns import qn
    trpr = tr.find(qn("w:trPr"))
    if trpr is not None:
        for e in trpr.findall(qn("w:tblHeader")):
            trpr.remove(e)
    for tc in tr.findall(qn("w:tc")):
        tcpr = tc.find(qn("w:tcPr"))
        if tcpr is not None:
            for e in tcpr.findall(qn("w:shd")):
                tcpr.remove(e)


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


def destino_multiloja(loja: int) -> dict[str, str]:
    """Migracao Multi Loja: o destino de cada linha e o que foi gravado PARA ESTA LOJA (pelo vinculo da migracao, os
    precos / saldos / titulos da loja). Linhas fora daqui (impostos federais, local de estoque, agente, familia) sao
    tabelas gerais e ficam com a contagem do VarejoFacil inteiro."""
    L = int(loja); V = "migracao_multiloja.vinculo"
    vinc = lambda tipo: f"SELECT count(*) FROM {V} WHERE loj_codigo = {L} AND tipo = '{tipo}'"
    PRODS = f"(SELECT codigo_vf FROM {V} WHERE loj_codigo = {L} AND tipo = 'produto')"
    CLIS = f"(SELECT codigo_vf FROM {V} WHERE loj_codigo = {L} AND tipo = 'cliente')"
    est = lambda cond: f"SELECT count(*) FROM estoque_resumo WHERE loc_codigo = 1 AND loj_codigo = {L} AND procod IN {PRODS} AND res_saldo {cond}"
    return {
        "Seção": vinc("secao"), "Grupo": vinc("grupo"), "Subgrupo": vinc("subgrupo"),
        "Loja": f"SELECT count(*) FROM pessoa_loja WHERE loj_codigo = {L}",
        "Funcionário": vinc("funcionario"), "Cliente": vinc("cliente"),
        "Limite de Crédito": f"SELECT count(*) FROM limite_de_credito WHERE lcr_valor > 0 AND cli_codigo IN {CLIS}",
        "Fornecedor": vinc("fornecedor"), "Produto": vinc("produto"),
        "Imp. Federais Produtos": f"SELECT count(*) FROM (SELECT DISTINCT ip.procod, f.impfedtip FROM impostos_federais_produto ip "
                                  f"JOIN impostos_federais f ON f.impfedsim = ip.impfedsim WHERE ip.procod IN {PRODS}) x",
        "Produto Com Auxiliar": f"SELECT count(*) FROM {V} v WHERE v.loj_codigo = {L} AND v.tipo = 'produto' "
                                "AND EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = v.codigo_vf)",
        "Produto Sem Auxiliar": f"SELECT count(*) FROM {V} v WHERE v.loj_codigo = {L} AND v.tipo = 'produto' "
                                "AND NOT EXISTS (SELECT 1 FROM produtoaux a WHERE a.procod = v.codigo_vf)",
        "Produto Fornecedor": f"SELECT count(*) FROM produto_fornecedor WHERE procod IN {PRODS}",
        "Preço Maior Que Zero": f"SELECT count(*) FROM preco WHERE lojcod = {L} AND procod IN {PRODS} AND prcvdavar > 0",
        "Preço Zero": f"SELECT count(*) FROM preco WHERE lojcod = {L} AND procod IN {PRODS} AND COALESCE(prcvdavar, 0) <= 0",
        "Tributação/Situação Fiscal": f"SELECT count(DISTINCT trbid) FROM produto WHERE trbid IS NOT NULL AND procod IN {PRODS}",
        "Produto Composição": f"SELECT count(DISTINCT comp_procod) FROM composicao WHERE comp_tipo IS NULL AND comp_procod IN {PRODS}",
        "Produto Kit": f"SELECT count(DISTINCT comp_procod) FROM composicao WHERE comp_tipo IS NOT NULL AND comp_procod IN {PRODS}",
        "Encarte": vinc("encarte"),
        "Estoque Positivo": est("> 0"), "Estoque Negativo": est("< 0"), "Estoque Zero": est("= 0"),
        "Contas Receber": f"SELECT count(*) FROM conta_a_receber WHERE loj_codigo = {L}",
        "Contas Pagar": f"SELECT count(*) FROM conta_a_pagar WHERE loj_codigo = {L}",
    }


def nome_arquivo(con_pg, nome_cliente: str, banco: str, loja: int | None = None) -> str:
    """'<Nome do Cliente> (<CNPJ>) - Validação de Migração.docx' (padrao da equipe). Nome vazio = razao social da
    loja matriz; CNPJ = documento da loja matriz no VarejoFacil. Tira os caracteres que o Windows nao aceita."""
    import re
    razao, cnpj = None, None
    try:
        with con_pg.transaction():
            r = con_pg.execute("SELECT p.pes_nome, p.pes_num_documento FROM pessoa_loja l JOIN pessoa p ON p.pes_codigo = l.pes_codigo "
                               + ("WHERE l.loj_codigo = %s" if loja else "WHERE l.loj_matriz = 'S' ORDER BY l.loj_codigo LIMIT 1"),
                               (int(loja),) if loja else None).fetchone()
            if r:
                razao, cnpj = r
    except Exception:
        pass
    nome = (nome_cliente or "").strip() or (razao or "").strip() or banco
    cnpj = re.sub(r"\D", "", cnpj or "")
    base = f"{nome} ({cnpj})" if cnpj else nome
    base = re.sub(r'[\\/:*?"<>|]+', " ", base)
    base = re.sub(r"\s+", " ", base).strip(" .")[:150] or "Cliente"
    return f"{base} - Validação de Migração" + (f" - Loja {int(loja)}" if loja else "") + ".docx"


def gerar(con_origem, con_pg, origem_tipo: str, opcoes: dict, conjunto: str, pasta: Path, versao: str,
          banco: str, log=print, respostas: dict | None = None, loja_destino: int | None = None) -> str | None:
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
    agora = time.strftime("%d/%m/%Y %H:%M")
    sistema = "SysPDV (SQL Server)" if origem_tipo == "sqlserver" else "SysPDV (Firebird)"
    t_mig, t_dados = _achar(doc, "Migração"), _achar(doc, "Dados Migrados")
    t_info, t_resp = _achar(doc, "Informações Complementares"), _achar(doc, "Respostas do analista")
    t_kpi, t_sf, t_imp = _achar(doc, "Tabelas conferidas"), _achar(doc, "Situação Fiscal"), _achar(doc, "Imposto")
    modelo_novo = t_kpi is not None or t_resp is not None

    # 1) dados da migracao
    resp = respostas or {}
    tipo_mig = ("Multi Loja (Loja " + str(int(loja_destino)) + ") — " if loja_destino else "") + ("Virada" if str(conjunto).endswith("virada") else "Inicial")
    if t_mig is not None:
        _preencher_por_rotulo(t_mig, {"Nome Cliente": resp.get("Nome Cliente") or "",
                                      "Analista de Migração": resp.get("Analista de Migração") or ""})
        _preencher_por_rotulo(t_mig, {"Migração": f"{tipo_mig} — {agora}",  # vira "Migração Inicial — data"
                                      "Sistema de Origem": sistema, "Sistema de Destino": f"VarejoFácil (banco {banco})",
                                      "Migrador Usado": f"migrador_syspdv_varejo {versao}"
                                                        + (f" — produtos com movimentação desde {MOV_DATA:%d/%m/%Y}" if MOV_DATA else "")})
    # 2) dados migrados: SysPDV x VarejoFacil (+ quadro-resumo do modelo novo)
    valores = {}
    por_loja = destino_multiloja(loja_destino) if loja_destino else {}
    for rotulo, sql_o, sql_d in _linhas(fora):
        valores[rotulo] = (_contar(con_origem, sql_o, False), _contar(con_pg, por_loja.get(rotulo, sql_d), True))
    if t_dados is not None:
        _tres_colunas(t_dados)
        _preencher_dados(t_dados, valores)
    if t_kpi is not None:
        r = _resumo(t_kpi, valores)
        log(f"Quadro-resumo: {r['tabelas conferidas']} tabelas conferidas, {r['sem divergencia']} sem divergência, "
            f"{r['com divergencia']} com divergência")

    # 3) informacoes complementares (produtos em linha / fora de linha / balanca: Origem x Destino) e as respostas
    #    do analista (mudou codigo de produto / de cliente). Modelo novo: duas tabelas proprias. Modelo antigo: uma
    #    tabela so, dividida em duas (Multi Loja e Juros e Multas sairam a pedido do usuario).
    if t_info is not None:
        from docx.oxml import OxmlElement
        from docx.table import Table
        if t_resp is None:
            copia_b = copy.deepcopy(t_info._tbl)
            _so_linhas(copia_b, {"mudou codigo produto", "mudou codigo cliente"})
            espaco = OxmlElement("w:p")
            t_info._tbl.addnext(espaco)
            espaco.addnext(copia_b)
            t_resp = Table(copia_b, t_info._parent)
        _so_linhas(t_info._tbl, {"produtos em linha", "produtos fora de linha", "produtos de balan"})
        _tres_colunas(t_info, "Informação")
        P = _filtro_produto(True)
        _preencher_dados(t_info, {
            "Produtos em Linha": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND COALESCE(p.PROFORLIN, 'N') = 'N'", False),
                                  _contar(con_pg, "SELECT count(*) FROM produto WHERE COALESCE(proforlin, 'N') = 'N'", True)),
            "Produtos fora de Linha": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND p.PROFORLIN = 'S'", False),
                                       _contar(con_pg, "SELECT count(*) FROM produto WHERE proforlin = 'S'", True)),
            "Produtos de Balança": (_contar(con_origem, f"SELECT COUNT(*) FROM PRODUTO p WHERE {P} AND p.PROENVBAL = 'S'", False),
                                    _contar(con_pg, "SELECT count(*) FROM produto WHERE proenvbal = 'S'", True)),
        })
    if t_resp is not None:
        _preencher_por_rotulo(t_resp, {"Mudou Codigo Produto": resp.get("Mudou Codigo Produto", "—"),
                                       "Mudou Codigo Cliente": resp.get("Mudou Codigo Cliente", "—")})

    # 4) situacao fiscal e impostos federais migrados, com a quantidade de produtos
    def consulta(sql):
        try:
            with con_pg.transaction():
                return [(str(a), f"{b:,}".replace(",", ".") + " produto(s)") for a, b in con_pg.execute(sql).fetchall()]
        except Exception:
            return []
    if t_sf is not None:
        _lista(t_sf, consulta("SELECT sf.stf_codigo || ' - ' || COALESCE(sf.stf_descricao_completa, sf.stf_descricao_reduzida, ''), "
                              "count(p.procod) FROM situacao_fiscal sf LEFT JOIN produto p ON p.stf_codigo = sf.stf_codigo "
                              "GROUP BY sf.stf_codigo, sf.stf_descricao_completa, sf.stf_descricao_reduzida ORDER BY sf.stf_codigo"))
    if t_imp is not None:
        _lista(t_imp, consulta("SELECT f.impfedsim || ' - ' || COALESCE(f.impfeddes, ''), count(i.procod) FROM impostos_federais f "
                               "LEFT JOIN impostos_federais_produto i ON i.impfedsim = f.impfedsim "
                               "GROUP BY f.impfedsim, f.impfeddes ORDER BY f.impfedsim"))
    # 5) divergencias explicadas (no fim): por que cada linha dos Dados Migrados nao bateu. Primeiro os motivos que o
    #    PROGRESSO registrou (pulados / nao migrados / erros desta migracao); senao as regras conhecidas (_motivo).
    if t_resp is not None:
        try:
            registrados = motivos_da_migracao(pasta.parent if Path(pasta).name == "relatorios" else Path(pasta), banco, loja_destino)
        except Exception:
            registrados = {}
        itens = []
        for rotulo, (o, d) in valores.items():
            if o is not None and d is not None and o != d:
                info = registrados.get(rotulo)
                if info and d < o and sum(len(v) for k in ("pulado", "nao_migrado") for v in info[k].values()) >= o - d \
                        and not info["erro"]:
                    itens.append((rotulo, o, d, True, "registrado na migração — " + _texto_motivos(info)))
                    continue
                esperada, texto = _motivo(rotulo, o, d, con_origem, con_pg, loja_destino)
                if info and info["erro"]:
                    esperada, texto = False, "registrado na migração — " + _texto_motivos(info)
                itens.append((rotulo, o, d, esperada, texto))
        _secao_divergencias(doc, t_resp._tbl, itens)
        log(f"Divergências explicadas: {len(itens)} ({sum(1 for i in itens if i[3])} esperadas)")
        # 6) todos os registros nao migrados com o motivo do Progresso (mesmo nas linhas que bateram)
        reg = [(linha, None, None, None, _texto_motivos(info)) for linha, info in
               sorted(registrados.items(), key=lambda x: [r for r, _, _ in _linhas(fora)].index(x[0]) if x[0] in [r for r, _, _ in _linhas(fora)] else 99)]
        _secao_divergencias(doc, t_resp._tbl, reg, "Registros não migrados (motivos do Progresso)",
                            ("Nenhum registro", "nenhum pulado, erro ou não migrado registrado nas migrações deste banco "
                             "(ou migrado com versão anterior à 2026.11.57: rode a migração de novo para registrar)."))
        log(f"Registros não migrados (do Progresso): {len(reg)} item(ns)")
    if not modelo_novo:
        _bordas_pretas(doc)        # so o modelo antigo: o novo tem bordas proprias (e o visual dele)
    nome = nome_arquivo(con_pg, resp.get("Nome Cliente") or "", banco, loja_destino)
    destino = Path(pasta) / time.strftime("formulario_%Y%m%d_%H%M%S")      # pasta por geracao: o nome se repete
    destino.mkdir(parents=True, exist_ok=True)
    doc.save(str(destino / nome))
    nome = f"{destino.name}/{nome}"
    log(f"Formulário de validação gerado: {nome}")
    return nome
