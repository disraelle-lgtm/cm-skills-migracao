import asyncio, json, threading, time
import pytest
import aprovacoes, aprovar_migracao, migracao, server


def pedir(amb, **kw):
    args = dict(origem="origem", destino="pg_destino", itens=["01_secao"], simular=True)
    args.update(kw)
    return server.solicitar_execucao(**args)


def aprovar(pid):
    p = aprovacoes.carregar(pid)
    frase = p["resumo"]["frase_confirmacao"]
    assert aprovar_migracao.main([pid], entrada=lambda _="": frase, saida=lambda *_: None, interativo=True) == 0


# ------------------------------------------------------------------ leitura
def test_listar_itens_marca_automaticos(amb_mig):
    itens = {i["id"]: i for i in server.listar_itens_migracao("inicial")}
    assert itens["99_fila_panama"]["automatico"].startswith("sempre")
    assert "Cadastro de Pessoas" in itens["19_ajustes_pessoas"]["automatico"]
    assert itens["01_secao"]["automatico"] is None


def test_status_migrador(amb_mig):
    assert server.status_migrador()["versao"] == "2026.10.31"


def test_status_migrador_fechado(amb_mig):
    amb_mig.fake.parar()
    r = server.status_migrador()
    assert r["aberto"] is False and "iniciar-app" in r["detalhe"]


def test_leitura_recusa_conexao_de_migracao(amb_mig):
    with pytest.raises(ValueError, match="MIGRAÇÃO"):
        server.executar_consulta("pg_destino", "SELECT 1")
    with pytest.raises(ValueError, match="MIGRAÇÃO"):
        server.listar_tabelas("pg_destino")


def test_nenhuma_ferramenta_aprova_pedidos():
    nomes = {t.name for t in asyncio.run(server.mcp.list_tools())}
    assert not [n for n in nomes if "aprov" in n and n != "executar_pedido_aprovado"]
    assert "recusar" not in " ".join(nomes)
    assert not hasattr(server, "aprovar") and not hasattr(server.aprovacoes, "__mcp__")


# ------------------------------------------------------------------ pedido
def test_solicitar_nao_executa_nada(amb_mig):
    r = pedir(amb_mig)
    assert r["estado"] == "pendente" and r["frase_de_confirmacao"] == "SIMULAR"
    assert "NADA foi executado" in r["proximo_passo"]
    assert amb_mig.fake.posts("/migrar") == []


def test_itens_automaticos_aparecem_no_resumo(amb_mig):
    r = pedir(amb_mig)
    assert [i["id"] for i in r["resumo"]["itens_automaticos"]] == ["99_fila_panama"]
    r2 = pedir(amb_mig, itens=["09_cliente"])
    assert [i["id"] for i in r2["resumo"]["itens_automaticos"]] == ["19_ajustes_pessoas", "99_fila_panama"]


def test_item_automatico_nao_pode_ser_escolhido(amb_mig):
    with pytest.raises(ValueError, match="automáticos"):
        pedir(amb_mig, itens=["99_fila_panama"])
    with pytest.raises(ValueError, match="inexistentes"):
        pedir(amb_mig, itens=["77_nada"])


def test_item_com_problema_e_recusado(amb_mig):
    with pytest.raises(ValueError, match="problemas"):
        pedir(amb_mig, itens=["50_quebrado"])


def test_uma_etapa_por_aprovacao(amb_mig):
    with pytest.raises(ValueError, match="no máximo 1"):
        pedir(amb_mig, itens=["01_secao", "02_grupo"])


def test_destino_precisa_ser_postgres_de_migracao(amb_mig):
    with pytest.raises(ValueError, match="uso"):
        pedir(amb_mig, destino="pg_leitura")
    with pytest.raises(ValueError, match="PostgreSQL"):
        pedir(amb_mig, destino="origem")
    with pytest.raises(ValueError, match="Firebird ou SQL Server"):
        pedir(amb_mig, origem="pg_leitura")


def test_senhas_nunca_vao_para_o_arquivo_do_pedido(amb_mig):
    r = pedir(amb_mig, simular=False)
    texto = (amb_mig.tmp / "aprov" / f"{r['pedido_id']}.json").read_text(encoding="utf-8")
    assert "secreta" not in texto
    assert "secreta" not in json.dumps(r)


# ------------------------------------------------------------------ execução
def test_executar_sem_aprovacao_e_recusado(amb_mig):
    r = pedir(amb_mig)
    with pytest.raises(ValueError, match="NÃO aprovou"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []


def test_fluxo_completo(amb_mig):
    r = pedir(amb_mig, simular=True)
    aprovar(r["pedido_id"])
    res = server.executar_pedido_aprovado(r["pedido_id"])
    assert res["exec_id"] == "EX1" and res["simulacao"] is True
    (post,) = amb_mig.fake.posts("/migrar")
    corpo = post[2]
    assert corpo["modulos"] == ["01_secao"]                 # só o escolhido; o app inclui os automáticos
    assert corpo["simular"] is True and corpo["origem_tipo"] == "firebird" and corpo["conjunto"] == "inicial"
    assert corpo["firebird"]["senha"] == "senha-fb-secreta" and corpo["firebird"]["caminho"] == "C:\\d\\X.FDB"
    assert corpo["postgres"] == {"host": "srv", "port": 5432, "dbname": "varejo_cli", "user": "postgres", "password": "senha-pg-secreta"}
    st = server.status_pedido(r["pedido_id"])
    assert st["estado"] == "usada" and st["resultado"] == {"exec_id": "EX1"}


def test_migracao_real_envia_simular_falso(amb_mig):
    r = pedir(amb_mig, simular=False)
    aprovar(r["pedido_id"])
    server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar")[0][2]["simular"] is False


def test_cada_aprovacao_vale_uma_vez(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    server.executar_pedido_aprovado(r["pedido_id"])
    with pytest.raises(ValueError, match="já foi executado"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert len(amb_mig.fake.posts("/migrar")) == 1


def test_aprovar_um_nao_libera_outro(amb_mig):
    a, b = pedir(amb_mig), pedir(amb_mig, itens=["02_grupo"])
    aprovar(a["pedido_id"])
    with pytest.raises(ValueError, match="NÃO aprovou"):
        server.executar_pedido_aprovado(b["pedido_id"])


def test_duas_chamadas_ao_mesmo_tempo_executam_uma_vez(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    resultados, barreira = [], threading.Barrier(2)

    def tentar():
        barreira.wait()
        try:
            resultados.append(("ok", server.executar_pedido_aprovado(r["pedido_id"])))
        except ValueError as e:
            resultados.append(("erro", str(e)))
    ts = [threading.Thread(target=tentar) for _ in range(2)]
    [t.start() for t in ts]; [t.join() for t in ts]
    assert sorted(x[0] for x in resultados) == ["erro", "ok"]
    assert len(amb_mig.fake.posts("/migrar")) == 1


def test_pedido_expirado(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    arq = amb_mig.tmp / "aprov" / f"{r['pedido_id']}.json"
    d = json.loads(arq.read_text(encoding="utf-8")); d["expira_em"] = time.time() - 1
    arq.write_text(json.dumps(d), encoding="utf-8")
    with pytest.raises(ValueError, match="expirou"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []


def test_parametros_adulterados_depois_da_aprovacao(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    arq = amb_mig.tmp / "aprov" / f"{r['pedido_id']}.json"
    d = json.loads(arq.read_text(encoding="utf-8")); d["parametros"]["modulos"] = ["02_grupo"]; d["parametros"]["simular"] = False
    arq.write_text(json.dumps(d), encoding="utf-8")
    with pytest.raises(ValueError, match="alterados"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []
    assert server.status_pedido(r["pedido_id"])["estado"] == "invalidada"


def test_sql_editado_depois_da_aprovacao_derruba_o_pedido(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    (amb_mig.raiz / "comandos" / "01_secao" / "inserir.sql").write_text("DELETE FROM secao;", encoding="utf-8")
    with pytest.raises(ValueError, match="mudaram depois da aprovação"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []


def test_sql_de_item_automatico_editado_tambem_derruba(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    (amb_mig.raiz / "comandos" / "99_fila_panama" / "inserir.sql").write_text("-- outra coisa", encoding="utf-8")
    with pytest.raises(ValueError, match="mudaram"):
        server.executar_pedido_aprovado(r["pedido_id"])


def test_migrador_fechado_nao_consome_a_aprovacao(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    amb_mig.fake.parar()
    with pytest.raises(ValueError, match="Nada foi iniciado"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert server.status_pedido(r["pedido_id"])["estado"] == "aprovada"


def test_migrador_recusa_409_libera_e_da_para_tentar_de_novo(amb_mig):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    amb_mig.fake.migrar_resposta = (409, {"detail": "Já existe uma migração em andamento."})
    with pytest.raises(ValueError, match="em andamento"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert server.status_pedido(r["pedido_id"])["estado"] == "aprovada"
    amb_mig.fake.migrar_resposta = None
    assert server.executar_pedido_aprovado(r["pedido_id"])["exec_id"] == "EX1"


def test_resposta_incerta_nunca_repete(amb_mig, monkeypatch):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    original = migracao.Api.migrar
    def estourou(self, payload):
        raise migracao.ErroMigrador("O migrador não respondeu em 30s.")
    monkeypatch.setattr(migracao.Api, "migrar", estourou)
    with pytest.raises(ValueError, match="Não sei se a execução começou"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert server.status_pedido(r["pedido_id"])["estado"] == "indeterminada"
    monkeypatch.setattr(migracao.Api, "migrar", original)   # mesmo com o migrador de volta, NÃO repete
    with pytest.raises(ValueError, match="indeterminada"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []
    with pytest.raises(ValueError, match="indeterminada"):
        server.executar_pedido_aprovado(r["pedido_id"])


def test_senha_ausente_nao_consome_a_aprovacao(amb_mig, monkeypatch):
    r = pedir(amb_mig)
    aprovar(r["pedido_id"])
    monkeypatch.delenv("T_PG")
    with pytest.raises(ValueError, match="T_PG"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert server.status_pedido(r["pedido_id"])["estado"] == "aprovada"
    assert amb_mig.fake.posts("/migrar") == []


def test_app_url_precisa_ser_local(amb_mig):
    d = json.loads(amb_mig.cfg_arq.read_text(encoding="utf-8")); d["app_url"] = "http://servidor-externo:8020"
    amb_mig.cfg_arq.write_text(json.dumps(d), encoding="utf-8")
    with pytest.raises(ValueError, match="próprio computador"):
        pedir(amb_mig)


# ------------------------------------------------------------------ virada e códigos
def test_virada_com_arquivo_de_codigos(amb_mig, tmp_path):
    csv = tmp_path / "prod.csv"; csv.write_text("antigo;novo\n1;2\n", encoding="utf-8")
    r = pedir(amb_mig, conjunto="virada", itens=["20_virada_codigos_produto"], depara_produtos_arquivo=str(csv))
    aprovar(r["pedido_id"])
    server.executar_pedido_aprovado(r["pedido_id"])
    corpo = amb_mig.fake.posts("/migrar")[0][2]
    assert corpo["conjunto"] == "virada" and corpo["depara_produtos"] == "antigo;novo\n1;2\n"


def test_arquivo_de_codigos_alterado_derruba_o_pedido(amb_mig, tmp_path):
    csv = tmp_path / "prod.csv"; csv.write_text("antigo;novo\n1;2\n", encoding="utf-8")
    r = pedir(amb_mig, conjunto="virada", itens=["20_virada_codigos_produto"], depara_produtos_arquivo=str(csv))
    aprovar(r["pedido_id"])
    csv.write_text("antigo;novo\n1;999\n", encoding="utf-8")
    with pytest.raises(ValueError, match="arquivo de códigos"):
        server.executar_pedido_aprovado(r["pedido_id"])
    assert amb_mig.fake.posts("/migrar") == []


def test_arquivo_de_codigos_so_na_virada(amb_mig, tmp_path):
    csv = tmp_path / "x.csv"; csv.write_text("a", encoding="utf-8")
    with pytest.raises(ValueError, match="virada"):
        pedir(amb_mig, depara_clientes_arquivo=str(csv))


def test_ajuste_de_codigos_tambem_exige_aprovacao(amb_mig):
    r = server.solicitar_ajuste_codigos("pg_destino", clientes=True)
    assert r["frase_de_confirmacao"] == "varejo_cli" and amb_mig.fake.posts("/codigos/ajustar") == []
    with pytest.raises(ValueError, match="NÃO aprovou"):
        server.executar_pedido_aprovado(r["pedido_id"])
    aprovar(r["pedido_id"])
    assert server.executar_pedido_aprovado(r["pedido_id"])["ajuste_id"] == "AJ1"
    (post,) = amb_mig.fake.posts("/codigos/ajustar")
    assert post[2]["clientes"] is True and post[2]["produtos"] is False and post[2]["postgres"]["password"] == "senha-pg-secreta"


def test_consultar_codigos_e_leitura_livre(amb_mig):
    r = server.consultar_codigos("pg_leitura", clientes=True)
    assert r["clientes"]["quantidade"] == 2
    assert amb_mig.fake.posts("/codigos/ajustar") == [] and amb_mig.fake.posts("/migrar") == []


# ------------------------------------------------------------------ acompanhamento
def test_status_execucao_enxuto(amb_mig):
    amb_mig.fake.status["log"] = [f"l{i}" for i in range(500)]; amb_mig.fake.status["total_log"] = 500
    r = server.status_execucao("EX1")
    assert len(r["log"]) == 60 and r["log"][-1] == "l499" and r["log_cortado"] is True
    assert "inicio_ts" not in r["itens"]["01_secao"] and r["itens"]["01_secao"]["lidos"] == 10


def test_codigo_de_pedido_invalido(amb_mig):
    with pytest.raises(ValueError, match="inválido"):
        server.status_pedido("../../etc/passwd")
    with pytest.raises(ValueError, match="não existe"):
        server.status_pedido("ABCDEF")
