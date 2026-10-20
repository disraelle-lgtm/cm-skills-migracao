\echo '======================================='
\echo '🔧 ETAPA 1: CRIANDO CAMPO TEMPORÁRIO...'
\echo '======================================='
ALTER TABLE pessoa_cliente ADD COLUMN IF NOT EXISTS codigo_cliente_antigo int8;
\echo '✅ Campo "codigo_cliente_antigo" criado com sucesso!'

\echo '========================================='
\echo '💾 ETAPA 2: SALVANDO OS CÓDIGOS ATUAIS...'
\echo '========================================='
UPDATE pessoa_cliente SET codigo_cliente_antigo = cli_codigo;
\echo '✅ Código de cliente salvo com sucesso!'

\echo '============================================'
\echo '🔧 ETAPA 3: EXECUTANDO SCRIPT DE CORREÇÃO...'
\echo '   (clientes com código >= 999999)'
\echo '============================================'

DO $$
DECLARE
   codigoAntigo pessoa_cliente.cli_codigo%TYPE;
   proximoCodigo pessoa_cliente.cli_codigo%TYPE;
BEGIN
   FOR codigoAntigo IN SELECT cli_codigo FROM pessoa_cliente WHERE cli_codigo >= 999999 ORDER BY cli_codigo
   LOOP
       SELECT CASE
           WHEN (SELECT MIN(p1.cli_codigo) FROM pessoa_cliente p1) > 1 THEN 1
           WHEN (SELECT MIN(p1.cli_codigo) FROM pessoa_cliente p1) IS NULL THEN 1
           ELSE (
               SELECT MIN(p1.cli_codigo+1)
               FROM pessoa_cliente p1
               LEFT JOIN (SELECT cli_codigo - 1 AS codigo FROM pessoa_cliente) p2
                 ON p1.cli_codigo = p2.codigo
               WHERE p2.codigo IS NULL
           )
       END INTO proximoCodigo;

       -- segurança: nunca troca por outro código que também quebra o Varejo
       IF proximoCodigo IS NULL OR proximoCodigo >= 999999 THEN
           RAISE EXCEPTION 'Não há código de cliente livre abaixo de 999999 (cliente %)', codigoAntigo;
       END IF;

       UPDATE pessoa_cliente SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;
       UPDATE limite_de_credito SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;
       UPDATE conta_a_receber SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;
       UPDATE cobranca SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;
       UPDATE transacao_liquidacao SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;
       UPDATE transacao_venda_prazo SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo;

       RAISE NOTICE 'CODIGO ANTIGO: %, CODIGO NOVO: %', codigoAntigo, proximoCodigo;
   END LOOP;
END;
$$;
