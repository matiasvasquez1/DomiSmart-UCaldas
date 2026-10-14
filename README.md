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
