import json
import pytest
import aprovacoes, aprovar_migracao, server


def _pedido(amb, **kw):
    args = dict(origem="origem", destino="pg_destino", itens=["01_secao"], simular=True)
    args.update(kw)
    return server.solicitar_execucao(**args)


def _digitar(*respostas):
    it = iter(respostas)
    return lambda _prompt="": next(it)


def test_aprova_com_a_frase_certa(amb_mig):
    r = _pedido(amb_mig)
    saidas = []
    cod = aprovar_migracao.main([r["pedido_id"]], entrada=_digitar("SIMULAR"), saida=saidas.append, interativo=True)
    assert cod == 0 and aprovacoes.carregar(r["pedido_id"])["estado"] == "aprovada"
    assert aprovacoes.carregar(r["pedido_id"])["aprovador"]


def test_frase_errada_ou_vazia_nao_aprova(amb_mig):
    r = _pedido(amb_mig)
    for resp in ("simular", "SIM", "varejo_cli", ""):
        assert aprovar_migracao.main([r["pedido_id"]], entrada=_digitar(resp), saida=lambda *_: None, interativo=True) == 1
        assert aprovacoes.carregar(r["pedido_id"])["estado"] == "pendente"


def test_real_exige_o_nome_do_banco_de_destino(amb_mig):
    r = _pedido(amb_mig, simular=False)
    assert r["frase_de_confirmacao"] == "varejo_cli"
    assert aprovar_migracao.main([r["pedido_id"]], entrada=_digitar("SIMULAR"), saida=lambda *_: None, interativo=True) == 1
    assert aprovacoes.carregar(r["pedido_id"])["estado"] == "pendente"
    assert aprovar_migracao.main([r["pedido_id"]], entrada=_digitar("varejo_cli"), saida=lambda *_: None, interativo=True) == 0


def test_sem_terminal_interativo_nao_aprova(amb_mig):
    r = _pedido(amb_mig)
    saidas = []
    cod = aprovar_migracao.main([r["pedido_id"]], entrada=_digitar("SIMULAR"), saida=saidas.append, interativo=False)
    assert cod == 2 and "interativo" in " ".join(saidas)
    assert aprovacoes.carregar(r["pedido_id"])["estado"] == "pendente"


def test_tela_mostra_itens_automaticos_e_avisos(amb_mig):
    r = _pedido(amb_mig, simular=False)
    saidas = []
    aprovar_migracao.main([r["pedido_id"]], entrada=_digitar(""), saida=saidas.append, interativo=True)
    tela = "\n".join(saidas)
    assert "GRAVA NO BANCO" in tela and "99_fila_panama" in tela and "apaga fila_sincronizacao" in tela
    assert "01_secao" in tela and "varejo_cli" in tela
    assert "senha" not in tela.lower().replace("usuário", "")


def test_recusar(amb_mig):
    r = _pedido(amb_mig)
    assert aprovar_migracao.main([r["pedido_id"], "--recusar"], saida=lambda *_: None, interativo=False) == 0
    assert aprovacoes.carregar(r["pedido_id"])["estado"] == "recusada"
    with pytest.raises(ValueError, match="recusou"):
        server.executar_pedido_aprovado(r["pedido_id"])


def test_listar_pendentes(amb_mig):
    a, b = _pedido(amb_mig), _pedido(amb_mig, itens=["02_grupo"])
    saidas = []
    aprovar_migracao.main([], saida=saidas.append, interativo=False)
    texto = "\n".join(saidas)
    assert a["pedido_id"] in texto and b["pedido_id"] in texto
