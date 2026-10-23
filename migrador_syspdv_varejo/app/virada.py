"""
De-para de codigos da MIGRACAO VIRADA (aba "Migracao Virada" da tela).

O fluxo da virada e o MESMO da migracao inicial (mesmos itens de comandos/). A diferenca: com o
arquivo de codigos anexado (planilha gerada na secao "4. Consultar codigos"), cada item troca o
codigo do SysPDV (antigo) pelo codigo do VarejoFacil (novo) antes de gravar. Sem o arquivo, o item
se comporta como na migracao inicial.

Arquivo: CSV com cabecalho, separador ; ou , - colunas CODIGO NOVO, CODIGO ANTIGO, nome/descricao
(formato das planilhas cod_novo_cod_antigo_*_todos_<banco>.csv; tambem aceita o formato do Pentaho:
codigo_novo / codigo_antigo ou Cod_Antigo).

Codigo NOVO na virada (registro que nao esta no arquivo = cadastrado no SysPDV depois da inicial):
  - produto de balanca: mantem o codigo (como no Pentaho);
  - produto cujo EAN ja foi trocado numa virada anterior (alteracao_produto_sped): reaproveita o
    mesmo codigo novo (rodar a virada de novo nao duplica o produto);
  - codigo valido (< 999999) que NAO pertence a outro registro pela planilha: mantem (e o proprio
    registro, novo ou de uma rodada anterior);
  - cliente que ja existe no VarejoFacil com o mesmo CPF/CNPJ (virada anterior): reaproveita o codigo;
  - EAN (>= 999999) ou codigo de outro registro: proximo codigo vago e valido (produtos: 10001 a
    999998; clientes: a partir de 1) - nunca o EAN. O EAN antigo vira codigo de barras (comandos_virada).
A relacao fica numa TABELA TEMPORARIA da conexao (mapa_codigos): os itens seguintes e os SQL da
virada a enxergam, e ela some sozinha no fim (nada permanente na base do cliente).
"""
from __future__ import annotations

import csv
import io

LIMITE = 999999
FAIXA = {"produto": (10001, 999998), "cliente": (1, 999998)}   # onde se CRIA codigo novo
VALIDO = (1, 999998)                                           # codigo valido no VarejoFacil (mantem)
TABELA_USADOS = {"produto": "SELECT procod FROM produto WHERE procod BETWEEN 1 AND 999998",
                 "cliente": "SELECT cli_codigo FROM pessoa_cliente WHERE cli_codigo BETWEEN 1 AND 999998"}


class ArquivoInvalido(Exception):
    pass


def ler_arquivo(texto: str, tipo: str) -> dict[int, int]:
    """CSV de codigos -> {codigo_antigo: codigo_novo}."""
    texto = (texto or "").lstrip("\ufeff")
    if not texto.strip():
        raise ArquivoInvalido(f"O arquivo de codigos de {tipo}s esta vazio.")
    primeira = texto.splitlines()[0]
    separador = ";" if primeira.count(";") >= primeira.count(",") else ","
    linhas = list(csv.reader(io.StringIO(texto), delimiter=separador))
    cab = [c.strip().lower().replace(" ", "_") for c in linhas[0]]
    try:
        i_novo = cab.index("codigo_novo")
        i_antigo = next(cab.index(n) for n in ("codigo_antigo", "cod_antigo") if n in cab)
    except (ValueError, StopIteration):
        raise ArquivoInvalido(
            f"O arquivo de {tipo}s precisa das colunas CODIGO NOVO e CODIGO ANTIGO no cabecalho "
            f"(encontrado: {linhas[0]}). Use a planilha gerada na secao 4 (Download).")
    mapa = {}
    for n, l in enumerate(linhas[1:], start=2):
        if not l or len(l) <= max(i_novo, i_antigo) or not l[i_antigo].strip():
            continue
        try:
            mapa[int(l[i_antigo].strip())] = int(l[i_novo].strip())
        except ValueError:
            raise ArquivoInvalido(f"Arquivo de {tipo}s, linha {n}: codigo nao numerico: {l}")
    if not mapa:
        raise ArquivoInvalido(f"O arquivo de codigos de {tipo}s nao tem nenhum codigo.")
    return mapa


class Depara:
    """Relacao antigo -> novo de clientes e/ou produtos durante uma execucao da virada."""

    def __init__(self, mapas: dict[str, dict[int, int]]):
        self.mapas = {t: dict(m) for t, m in mapas.items() if m}
        # codigos do VarejoFacil que, pela planilha, pertencem a algum registro (destinos do de-para)
        self.destinos = {t: {n for a, n in m.items()} for t, m in self.mapas.items()}
        self.usados: dict[str, set] = {}
        self.proximo: dict[str, int] = {}
        self.con = None

    def tipos(self) -> list[str]:
        return list(self.mapas)

    # ---------------------------------------------------------------- conexao / tabela temporaria
    def preparar(self, con, log) -> None:
        """Cria a tabela temporaria mapa_codigos e carrega os arquivos anexados."""
        self.con = con
        con.execute("CREATE TEMP TABLE IF NOT EXISTS mapa_codigos (tipo text, codigo_antigo bigint, "
                    "codigo_novo bigint, novo_na_virada boolean DEFAULT false)")
        con.execute("DELETE FROM mapa_codigos")
        with con.cursor().copy("COPY mapa_codigos (tipo, codigo_antigo, codigo_novo) FROM STDIN") as cp:
            for tipo, mapa in self.mapas.items():
                for antigo, novo in mapa.items():
                    cp.write_row((tipo, antigo, novo))
        for tipo, mapa in self.mapas.items():
            alterados = sum(1 for a, n in mapa.items() if a != n)
            log(f"De-para de {tipo}s: {len(mapa)} codigo(s) no arquivo, {alterados} com codigo alterado")
        # produtos novos de uma VIRADA ANTERIOR (EAN trocado por codigo novo, gravado no SPED):
        # entram no de-para para nao ganharem outro codigo ao rodar de novo
        if "produto" in self.mapas and con.execute("SELECT to_regclass('alteracao_produto_sped')").fetchone()[0]:
            anteriores = con.execute(
                "SELECT DISTINCT ON (aps_procod_anterior) aps_procod_anterior, procod FROM alteracao_produto_sped "
                "WHERE aps_procod_anterior IS NOT NULL AND aps_procod_anterior <> procod "
                "ORDER BY aps_procod_anterior, aps_codigo DESC").fetchall()
            novos = [(a, n) for a, n in anteriores if a not in self.mapas["produto"]]
            for a, n in novos:
                self.mapas["produto"][a] = n
                self.destinos["produto"].add(n)
                con.execute("INSERT INTO mapa_codigos (tipo, codigo_antigo, codigo_novo, novo_na_virada) "
                            "VALUES ('produto', %s, %s, false)", (a, n))
            if novos:
                log(f"De-para de produtos: {len(novos)} codigo(s) trocado(s) numa virada anterior reaproveitado(s)")

    def _carregar_usados(self, tipo: str) -> None:
        if tipo in self.usados:
            return
        usados = {r[0] for r in self.con.execute(TABELA_USADOS[tipo]).fetchall()}
        usados |= set(self.mapas.get(tipo, {}).values())
        self.usados[tipo] = usados
        self.proximo[tipo] = FAIXA[tipo][0]

    def _proximo_livre(self, tipo: str) -> int:
        inicio, fim = FAIXA[tipo]
        n = self.proximo[tipo]
        while n in self.usados[tipo]:
            n += 1
        if n > fim:
            raise RuntimeError(f"Nao ha mais codigo de {tipo} livre entre {inicio} e {fim}.")
        self.proximo[tipo] = n + 1
        return n

    # ---------------------------------------------------------------- traducao
    def traduzir(self, tipo: str, codigo, gerar: bool = False, manter: bool = False, candidatos=()):
        """Codigo do SysPDV -> codigo do VarejoFacil. gerar=True: registro novo ganha codigo
        (item principal: Cliente / Produto). manter=True: balanca, mantem o codigo."""
        if tipo not in self.mapas or codigo is None:
            return codigo
        mapa = self.mapas[tipo]
        antigo = int(codigo)
        if antigo in mapa:
            return mapa[antigo]
        if not gerar:
            return codigo                         # nao veio no arquivo e nao e o item principal
        self._carregar_usados(tipo)
        inicio, fim = FAIXA[tipo]
        destinos = self.destinos.get(tipo, set())
        livres = [c for c in candidatos if c is not None and c not in destinos]
        if manter or (VALIDO[0] <= antigo <= VALIDO[1] and antigo not in destinos):
            novo = antigo                 # balanca, ou codigo valido que nao e de outro registro
        elif livres:
            novo = int(livres[0])         # ja existe no VarejoFacil (ex.: mesmo CPF/CNPJ, virada anterior)
        else:
            novo = self._proximo_livre(tipo)
        self.usados[tipo].add(novo)
        destinos.add(novo)
        self.destinos[tipo] = destinos
        mapa[antigo] = novo
        self.con.execute("INSERT INTO mapa_codigos (tipo, codigo_antigo, codigo_novo, novo_na_virada) "
                         "VALUES (%s, %s, %s, true)", (tipo, antigo, novo))
        return novo

    # ---------------------------------------------------------------- planilhas finais
    def planilhas(self, con, pasta, banco: str) -> list[str]:
        """Planilhas finais (todos e alterados) de cada tipo carregado, como na secao 4."""
        consultas = {
            "produto": ("SELECT m.codigo_novo AS \"CODIGO NOVO\", m.codigo_antigo AS \"CODIGO ANTIGO\", p.prodes AS \"DESCRICAO\" "
                        "FROM mapa_codigos m LEFT JOIN produto p ON p.procod = m.codigo_novo WHERE m.tipo = 'produto'"),
            "cliente": ("SELECT m.codigo_novo AS \"CODIGO NOVO\", m.codigo_antigo AS \"CODIGO ANTIGO\", pe.pes_nome AS \"NOME CLIENTE\" "
                        "FROM mapa_codigos m LEFT JOIN pessoa_cliente pc ON pc.cli_codigo = m.codigo_novo "
                        "LEFT JOIN pessoa pe ON pe.pes_codigo = pc.pes_codigo WHERE m.tipo = 'cliente'"),
        }
        arquivos = []
        for tipo in self.mapas:
            for sufixo, filtro in (("todos", ""), ("alterados", " AND m.codigo_novo <> m.codigo_antigo")):
                cur = con.execute(consultas[tipo] + filtro + " ORDER BY 1")
                nome = f"virada_cod_novo_cod_antigo_{tipo}_{sufixo}_{banco}.csv"
                with open(pasta / nome, "w", newline="", encoding="utf-8-sig") as f:
                    w = csv.writer(f, delimiter=";")
                    w.writerow([d.name for d in cur.description])
                    w.writerows(cur.fetchall())
                arquivos.append(nome)
        return arquivos
