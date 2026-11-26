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

-- VERSAO OTIMIZADA do script do kit-migracao (mesmo resultado): o original, para CADA cliente, procurava o menor
-- codigo livre cruzando a pessoa_cliente com ela mesma e rodava 6 UPDATEs - ~1 cliente/segundo numa base real.
-- Aqui: (1) monta UMA vez o mapa codigo antigo -> codigo novo (os codigos >= 999999, em ordem crescente, recebem os
-- menores codigos livres de 1 a 999998, em ordem crescente - exatamente o que o laco do kit fazia um a um);
-- (2) atualiza cada tabela UMA vez pelo mapa; (3) avisa CODIGO ANTIGO / CODIGO NOVO de cada um (barra de progresso).
DO $$
DECLARE
   r record;
   total_antigos bigint;
   total_mapa bigint;
BEGIN
   CREATE TEMP TABLE mapa_cliente ON COMMIT DROP AS
   WITH antigos AS (
       SELECT cli_codigo AS antigo, row_number() OVER (ORDER BY cli_codigo) AS ordem
         FROM pessoa_cliente WHERE cli_codigo >= 999999
   ), livres AS (
       SELECT g AS novo, row_number() OVER (ORDER BY g) AS ordem
         FROM generate_series(1, 999998) g
        WHERE NOT EXISTS (SELECT 1 FROM pessoa_cliente p WHERE p.cli_codigo = g)
   )
   SELECT a.antigo, l.novo FROM antigos a JOIN livres l ON l.ordem = a.ordem;

   SELECT count(*) INTO total_antigos FROM pessoa_cliente WHERE cli_codigo >= 999999;
   SELECT count(*) INTO total_mapa FROM mapa_cliente;
   IF total_mapa < total_antigos THEN       -- seguranca (como no kit): nunca troca por outro codigo que quebra o Varejo
       RAISE EXCEPTION 'Não há código de cliente livre abaixo de 999999 para todos os % clientes', total_antigos;
   END IF;
   CREATE INDEX ON mapa_cliente (antigo);
   ANALYZE mapa_cliente;

   UPDATE pessoa_cliente        t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;
   UPDATE limite_de_credito     t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;
   UPDATE conta_a_receber       t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;
   UPDATE cobranca              t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;
   UPDATE transacao_liquidacao  t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;
   UPDATE transacao_venda_prazo t SET cli_codigo = m.novo FROM mapa_cliente m WHERE t.cli_codigo = m.antigo;

   FOR r IN SELECT antigo, novo FROM mapa_cliente ORDER BY antigo LOOP
       RAISE NOTICE 'CODIGO ANTIGO: %, CODIGO NOVO: %', r.antigo, r.novo;
   END LOOP;
END;
$$;
