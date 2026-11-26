-- =====================================================================
-- 01_ddl_estrutura.sql — LeadForge
-- Criação do schema, tabelas, constraints e índices (PostgreSQL 15+)
-- Banco: criar uma vez, fora deste script: CREATE DATABASE leadforge_db;
-- =====================================================================
DROP SCHEMA IF EXISTS leadforge CASCADE; -- permite reexecutar do zero
CREATE SCHEMA leadforge;
SET search_path TO leadforge, public;

-- ============================================================================
-- 1. TABELA: usuario
-- Armazena as credenciais de acesso e garante o isolamento de dados (REG-09)
-- e o consentimento explícito da LGPD no cadastro (RNF-02).
-- ============================================================================
CREATE TABLE leadforge.usuario (
    id              SERIAL PRIMARY KEY,
    nome            VARCHAR(120) NOT NULL,
    email           VARCHAR(150) NOT NULL,
    senha_hash      VARCHAR(255) NOT NULL,
    aceite_lgpd     BOOLEAN NOT NULL DEFAULT FALSE,
    ativo           BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizado_em   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_usuario_email UNIQUE (email),
    CONSTRAINT ck_usuario_aceite_lgpd CHECK (aceite_lgpd = TRUE),
    CONSTRAINT ck_usuario_email_formato CHECK (POSITION('@' IN email) > 1)
);

-- ============================================================================
-- 2. TABELA: perfil_freelancer (Relacionamento 1:1 com usuario)
-- Guarda preferências regionais e tom de comunicação do profissional (RF-01).
-- ============================================================================
CREATE TABLE leadforge.perfil_freelancer (
    id                  SERIAL PRIMARY KEY,
    usuario_id          INT NOT NULL,
    cidade              VARCHAR(100) NOT NULL,
    estado              CHAR(2) NOT NULL,
    tom_comunicacao     VARCHAR(20) NOT NULL DEFAULT 'amigavel',
    atualizado_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_perfil_usuario UNIQUE (usuario_id),
    CONSTRAINT fk_perfil_usuario FOREIGN KEY (usuario_id)
        REFERENCES leadforge.usuario (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT ck_perfil_estado_uf CHECK (CHAR_LENGTH(TRIM(estado)) = 2),
    CONSTRAINT ck_perfil_tom_comunicacao CHECK (
        tom_comunicacao IN ('formal', 'amigavel', 'direto')
    )
);

-- ============================================================================
-- 3. TABELA: habilidade
-- Catálogo normalizado de competências técnicas (1FN/3FN) para evitar listas
-- multivaloradas no perfil do freelancer.
-- ============================================================================
CREATE TABLE leadforge.habilidade (
    id          SERIAL PRIMARY KEY,
    nome        VARCHAR(60) NOT NULL,
    categoria   VARCHAR(30) NOT NULL DEFAULT 'frontend',

    CONSTRAINT uq_habilidade_nome UNIQUE (nome),
    CONSTRAINT ck_habilidade_categoria CHECK (
        categoria IN ('frontend', 'backend', 'design', 'seo', 'cms', 'outros')
    )
);

-- ============================================================================
-- 4. TABELA ASSOCIATIVA: perfil_habilidade (Resolve N:M perfil <-> habilidade)
-- ============================================================================
CREATE TABLE leadforge.perfil_habilidade (
    perfil_id           INT NOT NULL,
    habilidade_id       INT NOT NULL,
    nivel_proficiencia  VARCHAR(20) NOT NULL DEFAULT 'intermediario',

    CONSTRAINT pk_perfil_habilidade PRIMARY KEY (perfil_id, habilidade_id),
    CONSTRAINT fk_ph_perfil FOREIGN KEY (perfil_id)
        REFERENCES leadforge.perfil_freelancer (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_ph_habilidade FOREIGN KEY (habilidade_id)
        REFERENCES leadforge.habilidade (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT ck_ph_nivel CHECK (
        nivel_proficiencia IN ('basico', 'intermediario', 'avancado')
    )
);

-- ============================================================================
-- 5. TABELA: busca
-- Registra cada varredura assíncrona parametrizada por nicho e localidade (RF-02).
-- ============================================================================
CREATE TABLE leadforge.busca (
    id                  SERIAL PRIMARY KEY,
    usuario_id          INT NOT NULL,
    nicho               VARCHAR(100) NOT NULL,
    cidade              VARCHAR(100) NOT NULL,
    estado              CHAR(2) NOT NULL,
    limite_resultados   INT NOT NULL DEFAULT 10,
    status_busca        VARCHAR(20) NOT NULL DEFAULT 'pendente',
    total_encontradas   INT NOT NULL DEFAULT 0,
    total_duplicadas    INT NOT NULL DEFAULT 0,
    mensagem_erro       VARCHAR(255) NULL,
    criada_em           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finalizada_em       TIMESTAMP NULL,

    CONSTRAINT fk_busca_usuario FOREIGN KEY (usuario_id)
        REFERENCES leadforge.usuario (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT ck_busca_limite CHECK (limite_resultados BETWEEN 1 AND 50),
    CONSTRAINT ck_busca_totais CHECK (total_encontradas >= 0 AND total_duplicadas >= 0),
    CONSTRAINT ck_busca_status CHECK (
        status_busca IN (
            'pendente', 'buscando', 'deduplicando',
            'analisando', 'concluida', 'erro', 'cancelada'
        )
    )
);

-- ============================================================================
-- 6. TABELA: empresa
-- Cadastro centralizado de pessoas jurídicas públicas (REG-01, REG-08).
-- Evita redundância de dados cadastrais quando múltiplos freelancers prospectam
-- o mesmo estabelecimento.
-- ============================================================================
CREATE TABLE leadforge.empresa (
    id                  SERIAL PRIMARY KEY,
    external_place_id   VARCHAR(120) NOT NULL,
    nome                VARCHAR(160) NOT NULL,
    nicho               VARCHAR(100) NOT NULL,
    cidade              VARCHAR(100) NOT NULL,
    estado              CHAR(2) NOT NULL,
    endereco            VARCHAR(255) NULL,
    telefone            VARCHAR(30) NULL,
    url_site            VARCHAR(255) NULL,
    criada_em           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizada_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uq_empresa_external_id UNIQUE (external_place_id),
    CONSTRAINT ck_empresa_estado CHECK (CHAR_LENGTH(TRIM(estado)) = 2)
);

-- ============================================================================
-- 7. TABELA: evidencia
-- Armazena sinais técnicos públicos coletados no site da empresa (RF-04, RF-05).
-- ============================================================================
CREATE TABLE leadforge.evidencia (
    id                  SERIAL PRIMARY KEY,
    empresa_id          INT NOT NULL,
    tipo_evidencia      VARCHAR(35) NOT NULL,
    indica_problema     BOOLEAN NOT NULL DEFAULT TRUE,
    valor_detectado     VARCHAR(255) NOT NULL,
    nivel_certeza       VARCHAR(20) NOT NULL,
    origem_fonte        VARCHAR(120) NOT NULL,
    coletada_em         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_evidencia_empresa FOREIGN KEY (empresa_id)
        REFERENCES leadforge.empresa (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT ck_evidencia_tipo CHECK (
        tipo_evidencia IN (
            'HTTPS',
            'RESPONSIVIDADE_CELULAR',
            'BOTAO_WHATSAPP',
            'FORMULARIO_CONTATO',
            'CHAMADA_PARA_ACAO',
            'DISPONIBILIDADE_SITE'
        )
    ),
    CONSTRAINT ck_evidencia_certeza CHECK (
        nivel_certeza IN ('confirmado', 'sinal_forte', 'inferencia', 'desconhecido')
    )
);

-- ============================================================================
-- 8. TABELA ASSOCIATIVA: oportunidade (Resolve N:M usuario <-> empresa)
-- Representa cada lead na carteira isolada de um freelancer (REG-06, REG-09).
-- ============================================================================
CREATE TABLE leadforge.oportunidade (
    id                  SERIAL PRIMARY KEY,
    usuario_id          INT NOT NULL,
    empresa_id          INT NOT NULL,
    busca_id            INT NULL,
    pontuacao           NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    status_contato      VARCHAR(20) NOT NULL DEFAULT 'novo',
    observacoes         TEXT NULL,
    criada_em           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atualizada_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Garante REG-06: uma mesma empresa nunca aparece duplicada na carteira do usuário
    CONSTRAINT uq_oportunidade_usuario_empresa UNIQUE (usuario_id, empresa_id),
    CONSTRAINT fk_oportunidade_usuario FOREIGN KEY (usuario_id)
        REFERENCES leadforge.usuario (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_oportunidade_empresa FOREIGN KEY (empresa_id)
        REFERENCES leadforge.empresa (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT fk_oportunidade_busca FOREIGN KEY (busca_id)
        REFERENCES leadforge.busca (id)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    CONSTRAINT ck_oportunidade_pontuacao CHECK (pontuacao >= 0.00 AND pontuacao <= 100.00),
    CONSTRAINT ck_oportunidade_status CHECK (
        status_contato IN ('novo', 'contatado', 'respondeu', 'descartado')
    )
);

-- ============================================================================
-- 9. TABELA: sugestao_abordagem (Relacionamento 1:1 com oportunidade)
-- Armazena a explicação e o rascunho de abordagem gerados por IA (RF-07, RF-08).
-- ============================================================================
CREATE TABLE leadforge.sugestao_abordagem (
    id                  SERIAL PRIMARY KEY,
    oportunidade_id     INT NOT NULL,
    texto_explicacao    TEXT NOT NULL,
    rascunho_mensagem   TEXT NOT NULL,
    modelo_ia           VARCHAR(50) NOT NULL DEFAULT 'gpt-4o-mini',
    foi_editado         BOOLEAN NOT NULL DEFAULT FALSE,
    revisado_usuario    BOOLEAN NOT NULL DEFAULT FALSE,
    gerada_em           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    editada_em          TIMESTAMP NULL,

    CONSTRAINT uq_sugestao_oportunidade UNIQUE (oportunidade_id),
    CONSTRAINT fk_sugestao_oportunidade FOREIGN KEY (oportunidade_id)
        REFERENCES leadforge.oportunidade (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- ============================================================================
-- 10. TABELA: auditoria_oportunidade_log
-- Histórico imutável de alterações críticas de status e pontuação (alimentado
-- automaticamente via Trigger).
-- ============================================================================
CREATE TABLE leadforge.auditoria_oportunidade_log (
    id                  SERIAL PRIMARY KEY,
    oportunidade_id     INT NOT NULL,
    usuario_id          INT NOT NULL,
    acao                VARCHAR(20) NOT NULL,
    status_anterior     VARCHAR(20) NULL,
    status_novo         VARCHAR(20) NULL,
    pontuacao_anterior  NUMERIC(5,2) NULL,
    pontuacao_nova      NUMERIC(5,2) NULL,
    registrado_em       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ÍNDICES CUSTOMIZADOS (Justificados por consultas críticas e comprovados via EXPLAIN)
-- ============================================================================

-- Índice 1: Acelera a listagem principal ranqueada da carteira do usuário (/oportunidades)
CREATE INDEX idx_oportunidade_usuario_pontuacao
    ON leadforge.oportunidade (usuario_id, pontuacao DESC);

-- Índice 2: Otimiza filtragem por status do funil comercial (/oportunidades e /carteira)
CREATE INDEX idx_oportunidade_usuario_status
    ON leadforge.oportunidade (usuario_id, status_contato);

-- Índice 3: Acelera consultas territoriais por estado, cidade e nicho (RF-02 e Assistente)
CREATE INDEX idx_empresa_estado_cidade_nicho
    ON leadforge.empresa (estado, cidade, nicho);

-- Índice 4: Acelera agregação de evidências problemáticas e filtro por nível de certeza
CREATE INDEX idx_evidencia_empresa_problema_certeza
    ON leadforge.evidencia (empresa_id, indica_problema, nivel_certeza);
