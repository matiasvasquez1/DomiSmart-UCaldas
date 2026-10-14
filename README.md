# DomiSmart

Asistente inteligente para la consulta y recomendación de domicilios de comida.
Proyecto final de **Bases de Datos Relacionales**: sistema híbrido relacional-vectorial para RAG
(PostgreSQL + pgvector). Este repositorio contiene la **Entrega 1: diseño y configuración**.

## Qué hay en el repositorio

```
DomiSmart/
├── README.md                  este archivo
├── schema.sql                 DDL completo: 20 tablas relacionales + 4 vectoriales + índices + RLS
├── DomiSmart_Supabase.ipynb   notebook de Colab: conecta a Supabase, crea y verifica el esquema
├── .gitignore
└── diagramas/
    ├── erd_dominio.png / .mmd      ERD del dominio de domicilios (Crow's Foot)
    └── erd_nucleo_rag.png / .mmd   ERD del núcleo RAG y las tablas vectoriales
```

El documento de la entrega (universo del discurso, ERD, 3FN, campos vectorizables,
SQL, entorno y plan de chunking) está en el documento compartido del grupo.

## Tecnologías

- **Supabase**: PostgreSQL en la nube con la extensión pgvector
- **Google Colab**: Python 3 con `psycopg`, `pgvector`, `numpy`
- Esquema probado también en PostgreSQL 16.15 + pgvector 0.8.1
- Entrega 2: `sentence-transformers` (MiniLM, 384 dim.; CLIP ViT-B/32, 512 dim.), `Pillow`,
  `langchain-text-splitters`, `nltk`, `ragas`, un LLM gratuito (ej. Groq)

## Cómo configurar el entorno

1. Crear un proyecto gratuito en [supabase.com](https://supabase.com) y guardar la contraseña de la base.
2. En el proyecto: **Connect** → copiar la cadena del **Session pooler**
   (`postgresql://postgres.<ref>:<CONTRASEÑA>@aws-0-<region>.pooler.supabase.com:5432/postgres`).
   La *Direct connection* usa IPv6 y no funciona desde Colab.
3. Abrir `DomiSmart_Supabase.ipynb` en Colab → **Secrets** (ícono de llave) → secreto
   `DATABASE_URL` con esa cadena → activar el acceso del notebook.
4. Ejecutar las celdas en orden. La celda 4 pide subir `schema.sql`; la celda 5 debe terminar en
   "✅ Esquema correcto".

### Ejecutar schema.sql sin el notebook

Pegar el contenido de `schema.sql` en el **SQL Editor** de Supabase y pulsar *Run*.

⚠️ El script borra y recrea las 24 tablas. No lo vuelvan a ejecutar cuando ya haya datos cargados.

## Credenciales

La contraseña de Supabase va **solo** en los Secrets de Colab. Nunca la escriban en una celda:
si el notebook se sube a GitHub, queda pública. Si pasa, cámbienla en Supabase.

## Antes de entregar (pendiente del grupo)

- [ ] Nombres, códigos y correos de los integrantes en el documento
- [ ] Modalidad (pareja o terna). El modelo tiene 20 entidades y cumple ambos mínimos
- [ ] Crear el proyecto de Supabase y ejecutar el notebook hasta ver "✅ Esquema correcto"
- [ ] Crear el repositorio Git y poner su URL en el documento
- [ ] Revisar las fichas de los modelos en Hugging Face (dimensión y `max_seq_length`)

## Qué queda para la Entrega 2

- Cargar el catálogo, los documentos y las imágenes (con fuente y licencia)
- Chunking con las tres estrategias y embeddings de texto (MiniLM) e imágenes (CLIP), usando GPU de Colab
- Consultas SQL, vectoriales e híbridas de prueba
- Pipeline RAG con un LLM gratuito
- Evaluación RAGAS y experimento de chunking (10 preguntas × 3 estrategias)

## Subir al repositorio

```bash
git init
git add .
git commit -m "Entrega 1: diseño y configuración de DomiSmart"
git branch -M main
git remote add origin <URL-del-repositorio>
git push -u origin main
```
