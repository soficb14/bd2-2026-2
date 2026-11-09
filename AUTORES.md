# Autores — Sistema de Matrícula Acadêmica (BD II · 2026/2)

## Integrantes

- **Sofia** (@soficb14)
- **Pedro** (@nobony)
- **Victor** (@Naive05)

## Responsabilidade técnica formal (Seção 3 do edital)

Cada integrante responde por uma frente, na ordem em que aparecem no edital:

| Frente | Responsável | Entregas |
|---|---|---|
| 1. Modelagem Física e Desempenho | **Pedro** | DDL completo (`sql/01_tipos.sql`, `02_tabelas.sql`, `03_restricoes.sql`, `04_carga.sql`), índices incluindo parciais (`sql/07_indices.sql`) e evidências de `EXPLAIN (ANALYZE, BUFFERS)` antes/depois (`docs/INDICES_E_DESEMPENHO.md`, `docs/evidencias_indices.txt`) |
| 2. Transações e Concorrência | **Victor** | `sql/08_concorrencia.sql`, `scripts/medir_concorrencia.sh`, `docs/CONCORRENCIA.md`, `docs/evidencias_concorrencia.txt`: anomalia da última vaga, correção por `FOR UPDATE`, correção por `SERIALIZABLE` e comparação medida |
| 3. Administração e Operação | **Sofia** | `sql/06_views.sql`, `sql/09_seguranca.sql`, `scripts/backup.sh`, `scripts/restaurar.sh`, `docs/SEGURANCA_E_OPERACAO.md`, `docs/BACKUP_RESTAURACAO.md`, `docs/roteiro_demo_seguranca.sql` |

Apoio comum: o ambiente (`docker-compose.yml`, `scripts/rodar_tudo.ps1`), o `README.md` e a apresentação são trabalho dos três.

> Observação: mesmo com frentes definidas, todos os integrantes devem
> compreender o projeto inteiro — a arguição na apresentação é cruzada
> (Seção 6 do edital) e cada um pode ser questionado sobre a frente de
> um colega.

## Contribuições — Marco 1

| Frente | Responsável | Arquivos |
|---|---|---|
| Tipos, domínios, tabelas, restrições estruturais, trigger de vagas e índices | Sofia | `sql/01_tipos.sql`, `sql/02_tabelas.sql`, `sql/03_restricoes.sql` |
| Carga de dados do projeto (120 alunos, 300 matrículas) | Sofia | `sql/04_carga.sql` |
| 10 consultas de complexidade crescente | Pedro | `sql/05_consultas.sql` |
| Infraestrutura Docker, orquestração de containers | Victor | `docker-compose.yml`, ambiente pgAdmin |

O histórico de commits mostra quem fez o quê; as frentes acima não substituem a autoria registrada no Git.
