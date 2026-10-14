-- =====================================================================
-- DomiSmart — Entrega 1: esquema relacional + vectorial (PostgreSQL + pgvector)
-- Bases de Datos Relacionales · Proyecto final: Sistema híbrido RAG
--
-- Probado sobre una base vacía con PostgreSQL 16.15 + pgvector 0.8.1.
-- Entorno del proyecto: Supabase. Ejecutar desde el notebook DomiSmart_Supabase.ipynb
-- (celda 4) o pegando este archivo en el SQL Editor de Supabase.
--
-- Orden: extensión → catálogos → dominio → núcleo RAG → tablas vectoriales → índices
-- Convención: tablas en plural y sin tildes; PK "id_<entidad>".
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- Para poder re-ejecutar el script desde cero en desarrollo (orden inverso a la creación).
DROP TABLE IF EXISTS query_embeddings_clip, query_embeddings, embeddings_imagen, embeddings_texto,
    evaluaciones, resultados, consultas, imagen_etiquetas, etiquetas, imagenes, documentos,
    promocion_platos, promociones, oferta_platos, plato_ingredientes, ingredientes, platos,
    categorias_plato, sede_zonas, sedes, restaurantes, zonas_cobertura, ciudades, usuarios CASCADE;

-- ---------------------------------------------------------------------
-- 1. CATÁLOGOS Y UBICACIÓN
-- ---------------------------------------------------------------------

CREATE TABLE usuarios (
    id_usuario      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL,
    email           VARCHAR(150) NOT NULL UNIQUE,
    rol             VARCHAR(20)  NOT NULL DEFAULT 'cliente'
                    CHECK (rol IN ('cliente', 'administrador')),
    fecha_registro  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CHECK (email LIKE '%_@_%')
);

CREATE TABLE ciudades (
    id_ciudad     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(80) NOT NULL,
    departamento  VARCHAR(80) NOT NULL,
    UNIQUE (nombre, departamento)
);

CREATE TABLE zonas_cobertura (
    id_zona    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_ciudad  INT NOT NULL REFERENCES ciudades (id_ciudad) ON DELETE RESTRICT,
    nombre     VARCHAR(80) NOT NULL,           -- barrio o sector, ej. "Palermo"
    UNIQUE (id_ciudad, nombre)
);

-- ---------------------------------------------------------------------
-- 2. DOMINIO: RESTAURANTES, SEDES Y PLATOS
-- ---------------------------------------------------------------------

CREATE TABLE restaurantes (
    id_restaurante  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(120) NOT NULL UNIQUE,
    tipo_cocina     VARCHAR(60)  NOT NULL,     -- ej. "comida rápida", "italiana"
    descripcion     TEXT,
    activo          BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE sedes (
    id_sede         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_restaurante  INT NOT NULL REFERENCES restaurantes (id_restaurante) ON DELETE CASCADE,
    id_ciudad       INT NOT NULL REFERENCES ciudades (id_ciudad) ON DELETE RESTRICT,
    nombre          VARCHAR(100) NOT NULL,     -- ej. "Sede Cable"
    direccion       VARCHAR(200) NOT NULL,
    telefono        VARCHAR(20),
    hora_apertura   TIME NOT NULL,
    hora_cierre     TIME NOT NULL,
    activa          BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (id_restaurante, nombre),
    UNIQUE (id_sede, id_restaurante),           -- permite FK compuestas (ver oferta_platos)
    CHECK (hora_apertura <> hora_cierre)       -- se permite cruzar medianoche (cierre < apertura)
);

-- N:M Sede–ZonaCobertura (entidad asociativa con atributos propios)
CREATE TABLE sede_zonas (
    id_sede          INT NOT NULL REFERENCES sedes (id_sede) ON DELETE CASCADE,
    id_zona          INT NOT NULL REFERENCES zonas_cobertura (id_zona) ON DELETE CASCADE,
    costo_envio      NUMERIC(10,2) NOT NULL CHECK (costo_envio >= 0),
    tiempo_estimado  SMALLINT NOT NULL CHECK (tiempo_estimado BETWEEN 1 AND 240),  -- minutos
    PRIMARY KEY (id_sede, id_zona)
);

CREATE TABLE categorias_plato (
    id_categoria  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(60) NOT NULL UNIQUE,  -- ej. "Hamburguesas", "Postres"
    descripcion   TEXT
);

CREATE TABLE platos (
    id_plato        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_restaurante  INT NOT NULL REFERENCES restaurantes (id_restaurante) ON DELETE CASCADE,
    id_categoria    INT NOT NULL REFERENCES categorias_plato (id_categoria) ON DELETE RESTRICT,
    nombre          VARCHAR(120) NOT NULL,
    descripcion     TEXT NOT NULL,
    es_vegetariano  BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (id_restaurante, nombre),
    UNIQUE (id_plato, id_restaurante)           -- permite FK compuestas que garantizan mismo restaurante
);

CREATE TABLE ingredientes (
    id_ingrediente  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(80) NOT NULL UNIQUE,
    es_alergeno     BOOLEAN NOT NULL DEFAULT FALSE  -- ej. maní, gluten, lácteos
);

-- N:M Plato–Ingrediente
CREATE TABLE plato_ingredientes (
    id_plato        INT NOT NULL REFERENCES platos (id_plato) ON DELETE CASCADE,
    id_ingrediente  INT NOT NULL REFERENCES ingredientes (id_ingrediente) ON DELETE RESTRICT,
    es_opcional     BOOLEAN NOT NULL DEFAULT FALSE,  -- se puede pedir sin él
    PRIMARY KEY (id_plato, id_ingrediente)
);

-- N:M Sede–Plato: precio y disponibilidad dependen de la sede, no solo del plato.
-- La FK compuesta impide ofertar en una sede un plato de OTRO restaurante.
CREATE TABLE oferta_platos (
    id_sede         INT NOT NULL,
    id_plato        INT NOT NULL,
    id_restaurante  INT NOT NULL,
    precio          NUMERIC(10,2) NOT NULL CHECK (precio > 0),   -- pesos colombianos (COP)
    disponible      BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (id_sede, id_plato),
    FOREIGN KEY (id_sede, id_restaurante)  REFERENCES sedes  (id_sede, id_restaurante)  ON DELETE CASCADE,
    FOREIGN KEY (id_plato, id_restaurante) REFERENCES platos (id_plato, id_restaurante) ON DELETE CASCADE
);

CREATE TABLE promociones (
    id_promocion    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_restaurante  INT NOT NULL REFERENCES restaurantes (id_restaurante) ON DELETE CASCADE,
    titulo          VARCHAR(120) NOT NULL,
    condiciones     TEXT NOT NULL,              -- texto que también se vectoriza vía documentos
    tipo_descuento  VARCHAR(15) NOT NULL CHECK (tipo_descuento IN ('porcentaje', 'valor_fijo')),
    valor_descuento NUMERIC(10,2) NOT NULL CHECK (valor_descuento > 0),
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE NOT NULL,
    CHECK (fecha_fin >= fecha_inicio),
    CHECK (tipo_descuento <> 'porcentaje' OR valor_descuento <= 100),
    UNIQUE (id_promocion, id_restaurante)
);

-- N:M Promoción–Plato (una promoción solo aplica a platos de su mismo restaurante)
CREATE TABLE promocion_platos (
    id_promocion    INT NOT NULL,
    id_plato        INT NOT NULL,
    id_restaurante  INT NOT NULL,
    PRIMARY KEY (id_promocion, id_plato),
    FOREIGN KEY (id_promocion, id_restaurante) REFERENCES promociones (id_promocion, id_restaurante) ON DELETE CASCADE,
    FOREIGN KEY (id_plato, id_restaurante)     REFERENCES platos (id_plato, id_restaurante) ON DELETE CASCADE
);

-- ---------------------------------------------------------------------
-- 3. NÚCLEO RAG: DOCUMENTOS E IMÁGENES
-- ---------------------------------------------------------------------

CREATE TABLE documentos (
    id_doc           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_restaurante   INT REFERENCES restaurantes (id_restaurante) ON DELETE SET NULL,  -- NULL = documento general
    titulo           VARCHAR(200) NOT NULL,
    tipo_documento   VARCHAR(20)  NOT NULL
                     CHECK (tipo_documento IN ('menu', 'descripcion', 'promocion', 'resena', 'faq')),
    idioma           CHAR(2)      NOT NULL DEFAULT 'es' CHECK (idioma IN ('es', 'en')),
    fecha            DATE         NOT NULL,
    fuente           VARCHAR(300) NOT NULL,     -- URL o "creado por el grupo"
    licencia         VARCHAR(100) NOT NULL,     -- condiciones de uso documentadas
    contenido_texto  TEXT         NOT NULL CHECK (length(trim(contenido_texto)) > 0)
);

CREATE TABLE imagenes (
    id_img        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_doc        INT NOT NULL REFERENCES documentos (id_doc) ON DELETE CASCADE,
    id_plato      INT REFERENCES platos (id_plato) ON DELETE SET NULL,   -- plato que muestra, si aplica
    ruta_archivo  VARCHAR(300) NOT NULL UNIQUE,  -- ej. "data/img/hamburguesa_doble.jpg"
    descripcion   TEXT NOT NULL,
    autor_fuente  VARCHAR(200) NOT NULL,         -- trazabilidad: autor o sitio de origen
    licencia      VARCHAR(100) NOT NULL          -- ej. "CC BY 4.0", "foto propia"
);

-- Etiquetas atómicas (1FN): reemplaza la columna multivaluada "etiquetas" del enunciado
CREATE TABLE etiquetas (
    id_etiqueta  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(50) NOT NULL UNIQUE     -- ej. "frito", "picante", "postre"
);

CREATE TABLE imagen_etiquetas (
    id_img       INT NOT NULL REFERENCES imagenes (id_img) ON DELETE CASCADE,
    id_etiqueta  INT NOT NULL REFERENCES etiquetas (id_etiqueta) ON DELETE CASCADE,
    PRIMARY KEY (id_img, id_etiqueta)
);

-- ---------------------------------------------------------------------
-- 4. NÚCLEO RAG: CONSULTAS, RESULTADOS Y EVALUACIONES
-- ---------------------------------------------------------------------

CREATE TABLE consultas (
    id_consulta          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario           INT NOT NULL REFERENCES usuarios (id_usuario) ON DELETE RESTRICT,
    texto_pregunta       TEXT NOT NULL CHECK (length(trim(texto_pregunta)) > 0),
    fecha                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    estrategia_chunking  VARCHAR(20) NOT NULL
                         CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    respuesta_generada   TEXT,                   -- la llena el LLM (Entrega 2)
    respuesta_esperada   TEXT                    -- ground truth para context recall (solo set de prueba)
);

-- Una fila por documento o imagen recuperado en una consulta
CREATE TABLE resultados (
    id_resultado     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta      INT NOT NULL REFERENCES consultas (id_consulta) ON DELETE CASCADE,
    id_doc           INT REFERENCES documentos (id_doc) ON DELETE RESTRICT,
    id_img           INT REFERENCES imagenes (id_img) ON DELETE RESTRICT,
    posicion         SMALLINT NOT NULL CHECK (posicion >= 1),   -- 1 = más similar
    score_similitud  REAL NOT NULL CHECK (score_similitud BETWEEN -1 AND 1),  -- similitud coseno
    CHECK (num_nonnulls(id_doc, id_img) = 1),    -- exactamente uno: documento XOR imagen
    UNIQUE (id_consulta, id_doc),
    UNIQUE (id_consulta, id_img)
);

-- 1:1 con Consulta. UNIQUE garantiza "como máximo una" evaluación; que toda consulta
-- tenga la suya lo asegura el proceso de evaluación (Entrega 2), no la FK.
CREATE TABLE evaluaciones (
    id_eval            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta        INT NOT NULL UNIQUE REFERENCES consultas (id_consulta) ON DELETE CASCADE,
    faithfulness       REAL CHECK (faithfulness      BETWEEN 0 AND 1),
    answer_relevancy   REAL CHECK (answer_relevancy  BETWEEN 0 AND 1),
    context_recall     REAL CHECK (context_recall    BETWEEN 0 AND 1),
    context_precision  REAL CHECK (context_precision BETWEEN 0 AND 1),   -- opcional (nota extra)
    modelo_eval        VARCHAR(100) NOT NULL,
    fecha              TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 5. TABLAS VECTORIALES
--    Texto: MiniLM → 384 dimensiones. Imagen y texto→imagen: CLIP ViT-B/32 → 512.
-- ---------------------------------------------------------------------

CREATE TABLE embeddings_texto (
    id_embedding         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_doc               INT NOT NULL REFERENCES documentos (id_doc) ON DELETE CASCADE,
    chunk_id             INT NOT NULL CHECK (chunk_id >= 0),   -- posición del fragmento en el documento
    estrategia_chunking  VARCHAR(20) NOT NULL
                         CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    chunk_texto          TEXT NOT NULL,
    num_tokens           INT CHECK (num_tokens > 0),
    vector_embedding     VECTOR(384) NOT NULL,
    modelo               VARCHAR(100) NOT NULL,
    UNIQUE (id_doc, estrategia_chunking, chunk_id)
);

CREATE TABLE embeddings_imagen (
    id_embedding      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_img            INT NOT NULL REFERENCES imagenes (id_img) ON DELETE CASCADE,
    vector_embedding  VECTOR(512) NOT NULL,      -- calculado desde los PÍXELES, no desde la ruta
    modelo            VARCHAR(100) NOT NULL,
    UNIQUE (id_img, modelo)
);

-- Pregunta codificada con MiniLM: búsqueda texto→texto contra embeddings_texto
CREATE TABLE query_embeddings (
    id_qemb           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta       INT NOT NULL REFERENCES consultas (id_consulta) ON DELETE CASCADE,
    vector_embedding  VECTOR(384) NOT NULL,
    modelo            VARCHAR(100) NOT NULL,
    UNIQUE (id_consulta, modelo)
);

-- Pregunta codificada con el codificador de TEXTO de CLIP: búsqueda texto→imagen
-- contra embeddings_imagen (mismo espacio de 512 dimensiones).
CREATE TABLE query_embeddings_clip (
    id_qemb_clip      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta       INT NOT NULL REFERENCES consultas (id_consulta) ON DELETE CASCADE,
    vector_embedding  VECTOR(512) NOT NULL,
    modelo            VARCHAR(100) NOT NULL,
    UNIQUE (id_consulta, modelo)
);

-- ---------------------------------------------------------------------
-- 6. ÍNDICES
-- ---------------------------------------------------------------------

-- Vectoriales: HNSW con distancia coseno (operador <=>), la misma métrica de la búsqueda
CREATE INDEX idx_emb_texto_hnsw  ON embeddings_texto  USING hnsw (vector_embedding vector_cosine_ops);
CREATE INDEX idx_emb_imagen_hnsw ON embeddings_imagen USING hnsw (vector_embedding vector_cosine_ops);

-- B-tree para los filtros de las consultas híbridas y las FK más usadas
CREATE INDEX idx_emb_texto_estrategia ON embeddings_texto (estrategia_chunking);
CREATE INDEX idx_documentos_filtros   ON documentos (tipo_documento, idioma, fecha);
CREATE INDEX idx_documentos_rest      ON documentos (id_restaurante);
CREATE INDEX idx_imagenes_doc         ON imagenes (id_doc);
CREATE INDEX idx_imagenes_plato       ON imagenes (id_plato);
CREATE INDEX idx_platos_categoria     ON platos (id_categoria);
CREATE INDEX idx_oferta_precio        ON oferta_platos (precio) WHERE disponible;
CREATE INDEX idx_sedes_restaurante    ON sedes (id_restaurante);
CREATE INDEX idx_consultas_usuario    ON consultas (id_usuario);
CREATE INDEX idx_resultados_consulta  ON resultados (id_consulta);

-- ---------------------------------------------------------------------
-- 7. SEGURIDAD (Supabase)
--    Supabase publica las tablas de "public" en su API web con la clave anónima.
--    Activar RLS sin políticas cierra ese acceso. La conexión desde Colab usa el
--    usuario "postgres", dueño de las tablas, que no se ve afectado.
--    En un PostgreSQL normal este bloque no cambia nada.
-- ---------------------------------------------------------------------
DO $$
DECLARE t TEXT;
BEGIN
    FOR t IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END LOOP;
END $$;
