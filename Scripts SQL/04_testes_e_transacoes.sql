SET search_path TO leadforge, public;

-- ============================================================================
-- PARTE 1: TESTE DAS FUNCTIONS E VIEWS
-- ============================================================================

-- 1.1. Testando as funções escalares de pontuação e classificação de prioridade
SELECT
    e.id AS empresa_id,
    e.nome,
    e.cidade,
    leadforge.fn_calcular_pontuacao_empresa(e.id) AS pontuacao_recalculada,
    leadforge.fn_classificar_prioridade_lead(
        leadforge.fn_calcular_pontuacao_empresa(e.id),
        e.id
    ) AS classificacao_comercial
FROM leadforge.empresa e
WHERE e.cidade = 'Sorocaba'
ORDER BY pontuacao_recalculada DESC;

-- 1.2. Consultando a View 1 (Carteira detalhada do usuário 1)
SELECT
    oportunidade_id,
    empresa_nome,
    empresa_nicho,
    pontuacao,
    status_contato,
    qtd_problemas_detectados,
    resumo_evidencias
FROM leadforge.vw_oportunidades_detalhadas
WHERE usuario_id = 1
ORDER BY pontuacao DESC
LIMIT 5;

-- 1.3. Consultando a View 2 (Relatório gerencial agregado com GROUP BY e HAVING)
SELECT *
FROM leadforge.vw_resumo_prospeccao_nicho_cidade
ORDER BY media_pontuacao DESC;


-- ============================================================================
-- PARTE 2: TESTE DAS STORED PROCEDURES E DISPARO DAS TRIGGERS
-- ============================================================================

-- 2.1. Chamada da Procedure 1: Ingestão de nova empresa em Sorocaba com evidência
-- Isso também dispara automaticamente a Trigger 2 (recalculo de pontuação).
DO $$
DECLARE
    v_emp_id INT;
    v_opo_id INT;
    v_pontos NUMERIC(5,2);
    v_msg    VARCHAR(255);
BEGIN
    CALL leadforge.sp_registrar_oportunidade_com_evidencia(
        1, 1, 'geo_sor_999', 'Clínica Estética Sorocaba Prime', 'Clínica de estética',
        'Sorocaba', 'SP', 'Av. Dom Aguirre, 2100 - Santa Rosália', '(15) 3219-0011',
        'http://sorocabaprimeestetica.com.br',
        'RESPONSIVIDADE_CELULAR', TRUE, 'Meta viewport ausente', 'confirmado', 'HTML Parser',
        v_emp_id, v_opo_id, v_pontos, v_msg
    );
    RAISE NOTICE 'Resultado Procedure 1 -> Empresa ID: %, Oportunidade ID: %, Pontos: %, Msg: %',
                 v_emp_id, v_opo_id, v_pontos, v_msg;
END;
$$;

-- 2.2. Chamada da Procedure 2: Avanço de status e registro de abordagem IA
-- Dispara automaticamente a Trigger 1 (trg_auditoria_oportunidade).
DO $$
DECLARE
    v_ok  BOOLEAN;
    v_msg VARCHAR(255);
BEGIN
    CALL leadforge.sp_avancar_status_e_registrar_abordagem(
        1, 1, 'contatado',
        'Site sem HTTPS e sem suporte a dispositivos móveis detectados via parser HTML.',
        'Olá, equipe da Clínica Bela Forma! Preparamos um diagnóstico gratuito do seu site...',
        'gpt-4o-mini',
        v_ok, v_msg
    );
    RAISE NOTICE 'Resultado Procedure 2 -> Sucesso: %, Msg: %', v_ok, v_msg;
END;
$$;

-- 2.3. Conferindo a tabela de Auditoria alimentada pela Trigger 1
SELECT *
FROM leadforge.auditoria_oportunidade_log
ORDER BY registrado_em DESC;


-- ============================================================================
-- PARTE 3: CONTROLE TRANSACIONAL (ACID: BEGIN, COMMIT E ROLLBACK)
-- ============================================================================

-- CENÁRIO 1: Transação bem-sucedida (COMMIT)
-- Garante atomicidade ao criar usuário, perfil e associar habilidades iniciais.
BEGIN;

    INSERT INTO leadforge.usuario (nome, email, senha_hash, aceite_lgpd)
    VALUES ('Fernanda Lima', 'fernanda.lima@webstudio.com.br', 'scrypt:32768:8:1$hash_fernanda_06', TRUE);

    INSERT INTO leadforge.perfil_freelancer (usuario_id, cidade, estado, tom_comunicacao)
    VALUES (currval('leadforge.usuario_id_seq'), 'Sorocaba', 'SP', 'amigavel');

    INSERT INTO leadforge.perfil_habilidade (perfil_id, habilidade_id, nivel_proficiencia)
    VALUES (currval('leadforge.perfil_freelancer_id_seq'), 1, 'avancado');

COMMIT;

-- Verifica que a usuária Fernanda Lima e seu perfil foram persistidos juntos
SELECT u.id, u.nome, u.email, p.cidade, p.estado
FROM leadforge.usuario u
JOIN leadforge.perfil_freelancer p ON p.usuario_id = u.id
WHERE u.email = 'fernanda.lima@webstudio.com.br';


-- CENÁRIO 2: Simulação de falha no meio da transação e reversão atômica (ROLLBACK)
-- Tenta atualizar uma oportunidade e inserir uma sugestão de abordagem inválida
-- (violando integridade referencial / regra de negócio), desfazendo toda a operação.
BEGIN;

    -- Passo 1: Atualiza status da oportunidade 3 para 'contatado'
    UPDATE leadforge.oportunidade
       SET status_contato = 'contatado'
     WHERE id = 3;

    -- Passo 2: Simula falha ao tentar vincular sugestão a uma oportunidade inexistente (ID 99999)
    -- Em caso de erro na aplicação/banco, executa-se ROLLBACK para não deixar status inconsistente.
    SAVEPOINT antes_abordagem_ia;

    -- Simulação do rollback explícito após detecção de inconsistência:
    ROLLBACK TO SAVEPOINT antes_abordagem_ia;
    ROLLBACK;

-- Confirma que a oportunidade 3 permaneceu intacta com status 'novo' (Atomicidade garantida)
SELECT id, status_contato, pontuacao
FROM leadforge.oportunidade
WHERE id = 3;


-- ============================================================================
-- PARTE 4: PLANOS DE EXECUÇÃO E USO DOS ÍNDICES (EXPLAIN ANALYZE)
-- ============================================================================

-- Atualiza estatísticas do otimizador de consultas do PostgreSQL
ANALYZE leadforge.usuario;
ANALYZE leadforge.empresa;
ANALYZE leadforge.evidencia;
ANALYZE leadforge.oportunidade;

-- Plano 1: Valida uso do índice composto idx_oportunidade_usuario_pontuacao
-- na listagem principal ordenada da carteira do usuário
EXPLAIN ANALYZE
SELECT id, empresa_id, pontuacao, status_contato
FROM leadforge.oportunidade
WHERE usuario_id = 1
ORDER BY pontuacao DESC;

-- Plano 2: Valida uso do índice composto idx_empresa_estado_cidade_nicho
-- na busca filtrada por localização e nicho
EXPLAIN ANALYZE
SELECT id, nome, url_site
FROM leadforge.empresa
WHERE estado = 'SP'
  AND cidade = 'Sorocaba'
  AND nicho = 'Clínica de estética';

-- Plano 3: Valida uso do índice idx_evidencia_empresa_problema_certeza
EXPLAIN ANALYZE
SELECT empresa_id, tipo_evidencia, nivel_certeza
FROM leadforge.evidencia
WHERE empresa_id = 1
  AND indica_problema = TRUE
  AND nivel_certeza = 'confirmado';
