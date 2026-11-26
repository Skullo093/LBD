SET search_path TO leadforge, public;

-- ============================================================================
-- 1. VIEWS (VISÕES)
-- ============================================================================

-- VIEW 1: Visão detalhada das oportunidades da carteira (consolida 4 tabelas)
-- Alimenta diretamente a listagem principal (/oportunidades) e exportação (RF-06/RF-11).
CREATE OR REPLACE VIEW leadforge.vw_oportunidades_detalhadas AS
SELECT
    o.id                                    AS oportunidade_id,
    o.usuario_id,
    u.nome                                  AS freelancer_nome,
    e.id                                    AS empresa_id,
    e.nome                                  AS empresa_nome,
    e.nicho                                 AS empresa_nicho,
    e.cidade,
    e.estado,
    e.telefone,
    e.url_site,
    o.pontuacao,
    o.status_contato,
    COUNT(ev.id) FILTER (WHERE ev.indica_problema = TRUE) AS qtd_problemas_detectados,
    STRING_AGG(ev.tipo_evidencia || ' (' || ev.nivel_certeza || ')', ', ' ORDER BY ev.id)
        FILTER (WHERE ev.indica_problema = TRUE)          AS resumo_evidencias,
    CASE
        WHEN sa.id IS NOT NULL THEN TRUE
        ELSE FALSE
    END                                     AS possui_abordagem_ia,
    COALESCE(sa.revisado_usuario, FALSE)    AS abordagem_revisada,
    o.criada_em,
    o.atualizada_em
FROM leadforge.oportunidade o
INNER JOIN leadforge.usuario u
    ON u.id = o.usuario_id
INNER JOIN leadforge.empresa e
    ON e.id = o.empresa_id
LEFT JOIN leadforge.evidencia ev
    ON ev.empresa_id = e.id
LEFT JOIN leadforge.sugestao_abordagem sa
    ON sa.oportunidade_id = o.id
GROUP BY
    o.id, o.usuario_id, u.nome, e.id, e.nome, e.nicho,
    e.cidade, e.estado, e.telefone, e.url_site,
    o.pontuacao, o.status_contato, sa.id, sa.revisado_usuario,
    o.criada_em, o.atualizada_em;

-- VIEW 2: Visão analítica consolidando 4 tabelas com GROUP BY e HAVING
-- Responde a consultas gerenciais do painel e do Assistente Virtual (RF-09),
-- identificando nichos e cidades com pelo menos 2 oportunidades e média >= 50 pts.
CREATE OR REPLACE VIEW leadforge.vw_resumo_prospeccao_nicho_cidade AS
SELECT
    u.id                                            AS usuario_id,
    u.nome                                          AS freelancer_nome,
    e.estado,
    e.cidade,
    e.nicho,
    COUNT(DISTINCT o.id)                            AS total_oportunidades,
    ROUND(AVG(o.pontuacao), 2)                      AS media_pontuacao,
    MAX(o.pontuacao)                                AS maior_pontuacao,
    COUNT(DISTINCT o.id) FILTER (WHERE o.status_contato = 'novo')      AS qtd_novos,
    COUNT(DISTINCT o.id) FILTER (WHERE o.status_contato = 'contatado') AS qtd_contatados,
    COUNT(ev.id) FILTER (WHERE ev.indica_problema = TRUE)              AS total_evidencias_criticas
FROM leadforge.usuario u
INNER JOIN leadforge.oportunidade o
    ON o.usuario_id = u.id
INNER JOIN leadforge.empresa e
    ON e.id = o.empresa_id
LEFT JOIN leadforge.evidencia ev
    ON ev.empresa_id = e.id
GROUP BY
    u.id, u.nome, e.estado, e.cidade, e.nicho
HAVING
    COUNT(DISTINCT o.id) >= 2
    AND AVG(o.pontuacao) >= 50.00;


-- ============================================================================
-- 2. FUNCTIONS (FUNÇÕES ESCALARES DE REGRA DE NEGÓCIO)
-- ============================================================================

-- FUNCTION 1: Calcula a pontuação (0 a 100) de uma empresa com base nos pesos
-- oficiais das evidências problemáticas e nos multiplicadores de nível de certeza
-- definidos na especificação do LeadForge (Seção 5).
CREATE OR REPLACE FUNCTION leadforge.fn_calcular_pontuacao_empresa(p_empresa_id INT)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_soma_ponderada NUMERIC(10,2) := 0.00;
BEGIN
    SELECT COALESCE(SUM(
        (CASE ev.tipo_evidencia
            WHEN 'DISPONIBILIDADE_SITE'   THEN 80.00
            WHEN 'RESPONSIVIDADE_CELULAR' THEN 35.00
            WHEN 'HTTPS'                  THEN 25.00
            WHEN 'BOTAO_WHATSAPP'         THEN 20.00
            WHEN 'FORMULARIO_CONTATO'     THEN 15.00
            WHEN 'CHAMADA_PARA_ACAO'      THEN 10.00
            ELSE 0.00
        END)
        *
        (CASE ev.nivel_certeza
            WHEN 'confirmado'  THEN 1.00
            WHEN 'sinal_forte' THEN 0.85
            WHEN 'desconhecido' THEN 0.80
            WHEN 'inferencia'  THEN 0.60
            ELSE 0.50
        END)
    ), 0.00)
    INTO v_soma_ponderada
    FROM leadforge.evidencia ev
    WHERE ev.empresa_id = p_empresa_id
      AND ev.indica_problema = TRUE;

    -- Aplica o teto máximo de 100.00 pontos conforme regra RF-06
    RETURN LEAST(100.00, ROUND(v_soma_ponderada, 2));
END;
$$;

-- FUNCTION 2: Classifica a prioridade comercial do lead com base na pontuação
-- e na existência de pelo menos uma evidência com nível 'confirmado'.
CREATE OR REPLACE FUNCTION leadforge.fn_classificar_prioridade_lead(
    p_pontuacao NUMERIC(5,2),
    p_empresa_id INT
)
RETURNS VARCHAR(25)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tem_confirmado BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM leadforge.evidencia
        WHERE empresa_id = p_empresa_id
          AND indica_problema = TRUE
          AND nivel_certeza = 'confirmado'
    ) INTO v_tem_confirmado;

    IF p_pontuacao >= 75.00 AND v_tem_confirmado THEN
        RETURN 'CRITICA (Imediata)';
    ELSIF p_pontuacao >= 60.00 THEN
        RETURN 'ALTA';
    ELSIF p_pontuacao >= 35.00 THEN
        RETURN 'MEDIA';
    ELSE
        RETURN 'BAIXA';
    END IF;
END;
$$;


-- ============================================================================
-- 3. TRIGGERS (GATILHOS DE AUDITORIA E INTEGRIDADE AUTOMÁTICA)
-- ============================================================================

-- TRIGGER 1 (Auditoria): Registra automaticamente no log imutável qualquer
-- mudança de status_contato ou pontuacao na tabela oportunidade.
CREATE OR REPLACE FUNCTION leadforge.fn_trg_auditar_oportunidade()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (OLD.status_contato IS DISTINCT FROM NEW.status_contato)
       OR (OLD.pontuacao IS DISTINCT FROM NEW.pontuacao) THEN
        INSERT INTO leadforge.auditoria_oportunidade_log (
            oportunidade_id,
            usuario_id,
            acao,
            status_anterior,
            status_novo,
            pontuacao_anterior,
            pontuacao_nova
        ) VALUES (
            NEW.id,
            NEW.usuario_id,
            'UPDATE',
            OLD.status_contato,
            NEW.status_contato,
            OLD.pontuacao,
            NEW.pontuacao
        );
    END IF;

    NEW.atualizada_em := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_auditoria_oportunidade
    BEFORE UPDATE ON leadforge.oportunidade
    FOR EACH ROW
    EXECUTE FUNCTION leadforge.fn_trg_auditar_oportunidade();


-- TRIGGER 2 (Integridade / Regra de Negócio Automática):
-- Sempre que uma evidência técnica é inserida, alterada ou removida, recalcula
-- automaticamente a pontuação de todas as oportunidades vinculadas à empresa,
-- mantendo o ranking sempre consistente (RF-06).
CREATE OR REPLACE FUNCTION leadforge.fn_trg_sincronizar_pontuacao_evidencia()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_empresa_id INT;
    v_nova_pontuacao NUMERIC(5,2);
BEGIN
    v_empresa_id := COALESCE(NEW.empresa_id, OLD.empresa_id);
    v_nova_pontuacao := leadforge.fn_calcular_pontuacao_empresa(v_empresa_id);

    UPDATE leadforge.oportunidade
       SET pontuacao = v_nova_pontuacao
     WHERE empresa_id = v_empresa_id
       AND pontuacao IS DISTINCT FROM v_nova_pontuacao;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_recalcular_pontuacao_apos_evidencia
    AFTER INSERT OR UPDATE OR DELETE ON leadforge.evidencia
    FOR EACH ROW
    EXECUTE FUNCTION leadforge.fn_trg_sincronizar_pontuacao_evidencia();


-- ============================================================================
-- 4. STORED PROCEDURES (ROTINAS TRANSACIONAIS COM IN/OUT E TRATAMENTO DE ERRO)
-- ============================================================================

-- PROCEDURE 1: Pipeline atômico de ingestão de prospect (Upsert de Empresa +
-- Registro de Evidência + Deduplicação e Criação de Oportunidade na Carteira).
CREATE OR REPLACE PROCEDURE leadforge.sp_registrar_oportunidade_com_evidencia(
    IN  p_usuario_id            INT,
    IN  p_busca_id              INT,
    IN  p_external_place_id     VARCHAR(120),
    IN  p_nome_empresa          VARCHAR(160),
    IN  p_nicho                 VARCHAR(100),
    IN  p_cidade                VARCHAR(100),
    IN  p_estado                CHAR(2),
    IN  p_endereco              VARCHAR(255),
    IN  p_telefone              VARCHAR(30),
    IN  p_url_site              VARCHAR(255),
    IN  p_tipo_evidencia        VARCHAR(35),
    IN  p_indica_problema       BOOLEAN,
    IN  p_valor_detectado       VARCHAR(255),
    IN  p_nivel_certeza         VARCHAR(20),
    IN  p_origem_fonte          VARCHAR(120),
    OUT p_empresa_id            INT,
    OUT p_oportunidade_id       INT,
    OUT p_pontuacao_final       NUMERIC(5,2),
    OUT p_mensagem_retorno      VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1. Insere ou atualiza a empresa pública sem duplicar external_place_id
    INSERT INTO leadforge.empresa (
        external_place_id, nome, nicho, cidade, estado, endereco, telefone, url_site
    ) VALUES (
        p_external_place_id, p_nome_empresa, p_nicho, p_cidade, UPPER(p_estado),
        p_endereco, p_telefone, p_url_site
    )
    ON CONFLICT (external_place_id) DO UPDATE
        SET nome = EXCLUDED.nome,
            url_site = COALESCE(EXCLUDED.url_site, leadforge.empresa.url_site),
            atualizada_em = CURRENT_TIMESTAMP
    RETURNING id INTO p_empresa_id;

    -- 2. Registra a evidência técnica coletada (dispara trg_recalcular_pontuacao_apos_evidencia)
    INSERT INTO leadforge.evidencia (
        empresa_id, tipo_evidencia, indica_problema, valor_detectado, nivel_certeza, origem_fonte
    ) VALUES (
        p_empresa_id, p_tipo_evidencia, p_indica_problema, p_valor_detectado, p_nivel_certeza, p_origem_fonte
    );

    -- 3. Calcula a pontuação atualizada da empresa
    p_pontuacao_final := leadforge.fn_calcular_pontuacao_empresa(p_empresa_id);

    -- 4. Vincula à carteira do usuário respeitando REG-06 (sem duplicar na carteira)
    INSERT INTO leadforge.oportunidade (
        usuario_id, empresa_id, busca_id, pontuacao, status_contato
    ) VALUES (
        p_usuario_id, p_empresa_id, p_busca_id, p_pontuacao_final, 'novo'
    )
    ON CONFLICT (usuario_id, empresa_id) DO UPDATE
        SET pontuacao = EXCLUDED.pontuacao,
            busca_id = COALESCE(EXCLUDED.busca_id, leadforge.oportunidade.busca_id)
    RETURNING id INTO p_oportunidade_id;

    p_mensagem_retorno := 'Sucesso: Empresa e evidência processadas com pontuação ' || p_pontuacao_final;

EXCEPTION
    WHEN OTHERS THEN
        p_empresa_id := NULL;
        p_oportunidade_id := NULL;
        p_pontuacao_final := 0.00;
        p_mensagem_retorno := 'Erro ao processar oportunidade: ' || SQLERRM;
        RAISE;
END;
$$;

-- PROCEDURE 2: Atualiza o estágio do funil de contato e registra/atualiza a
-- sugestão de abordagem da IA garantindo isolamento de carteira (REG-09) e
-- revisão humana obrigatória (RNF-05).
CREATE OR REPLACE PROCEDURE leadforge.sp_avancar_status_e_registrar_abordagem(
    IN  p_oportunidade_id       INT,
    IN  p_usuario_id            INT,
    IN  p_novo_status           VARCHAR(20),
    IN  p_texto_explicacao      TEXT,
    IN  p_rascunho_mensagem     TEXT,
    IN  p_modelo_ia             VARCHAR(50),
    OUT p_sucesso               BOOLEAN,
    OUT p_mensagem              VARCHAR(255)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_dono_id INT;
BEGIN
    -- Verifica se a oportunidade existe e pertence ao usuário autenticado (REG-09)
    SELECT usuario_id INTO v_dono_id
      FROM leadforge.oportunidade
     WHERE id = p_oportunidade_id;

    IF v_dono_id IS NULL THEN
        RAISE EXCEPTION 'Oportunidade ID % não encontrada.', p_oportunidade_id;
    END IF;

    IF v_dono_id <> p_usuario_id THEN
        RAISE EXCEPTION 'Acesso negado (REG-09): Oportunidade pertence a outro usuário.';
    END IF;

    -- Atualiza o status do contato (dispara trg_auditoria_oportunidade)
    UPDATE leadforge.oportunidade
       SET status_contato = p_novo_status
     WHERE id = p_oportunidade_id;

    -- Insere ou atualiza a sugestão gerada por IA (marcando revisado_usuario = FALSE por segurança)
    INSERT INTO leadforge.sugestao_abordagem (
        oportunidade_id, texto_explicacao, rascunho_mensagem, modelo_ia, foi_editado, revisado_usuario
    ) VALUES (
        p_oportunidade_id, p_texto_explicacao, p_rascunho_mensagem, COALESCE(p_modelo_ia, 'gpt-4o-mini'), FALSE, FALSE
    )
    ON CONFLICT (oportunidade_id) DO UPDATE
        SET texto_explicacao = EXCLUDED.texto_explicacao,
            rascunho_mensagem = EXCLUDED.rascunho_mensagem,
            modelo_ia = EXCLUDED.modelo_ia,
            editada_em = CURRENT_TIMESTAMP,
			revisado_usuario = FALSE,
			foi_editado = FALSE;
    p_sucesso := TRUE;
    p_mensagem := 'Status atualizado para "' || p_novo_status || '" e abordagem registrada com sucesso.';

EXCEPTION
    WHEN OTHERS THEN
        p_sucesso := FALSE;
        p_mensagem := 'Falha na operação: ' || SQLERRM;
        RAISE;
END;
$$;
