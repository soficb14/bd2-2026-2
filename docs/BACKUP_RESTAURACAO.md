# Backup e restauração (reproduzível do zero)

**Frente:** Administração e Operação · **Scripts:** `scripts/backup.sh`, `scripts/restaurar.sh`
Todos os comandos abaixo rodam no **PowerShell**, na pasta do projeto, com o ambiente Docker no ar (`docker compose up -d`).

## O que é salvo, e por quê em dois arquivos

| Arquivo | Conteúdo | Observação |
|---|---|---|
| `marco3_AAAAMMDD_HHMMSS.dump` | Banco inteiro: schema, dados, índices, views, **policies de RLS**, **GRANTs**, trigger | Formato *custom* (`pg_dump -Fc`): comprimido e restaurável por partes com `pg_restore` |
| `globais_AAAAMMDD_HHMMSS.sql` | **Papéis** (roles) do servidor | Papéis são objetos do *cluster*, **não do banco**: `pg_dump` não os inclui. Gerado por `pg_dumpall --globals-only` |

Sem o segundo arquivo, restaurar em um servidor novo **falha** em `CREATE POLICY ... TO aluno` com `role "aluno" does not exist` (testado).

## 1. Fazer o backup

```powershell
docker cp scripts bd2_postgres:/tmp/
docker exec bd2_postgres bash /tmp/scripts/backup.sh
docker cp bd2_postgres:/backup/. ./backup
```

A última linha copia os arquivos para o **seu computador**. É obrigatória: o sistema de arquivos do contêiner é apagado em
`docker compose down` (e o volume do banco em `down -v`). Um backup que mora no mesmo lugar do que protege não é backup.

O script também confere o arquivo (`pg_restore -l`) para garantir que é legível.

## 2. Restaurar — demonstração ao vivo (mostra o ganho)

**a) Estado antes** (Query Tool, banco `marco3`):

```sql
SET search_path TO academico;
SELECT (SELECT count(*) FROM tb_matricula) AS matriculas, (SELECT count(*) FROM tb_historico WHERE media_geral IS NOT NULL) AS com_nota;  -- 300 | 240
```

**b) Desastre** (apaga o schema inteiro):

```powershell
docker exec bd2_postgres psql -U bd2 -d marco3 -c "DROP SCHEMA academico CASCADE"
```

No pgAdmin, *Refresh* no banco: o schema `academico` sumiu. Qualquer consulta falha.

**c) Restauração** (use o nome do arquivo gerado, veja com `docker exec bd2_postgres ls /backup`):

```powershell
docker exec bd2_postgres pg_restore -U bd2 -d marco3 --no-owner --exit-on-error /backup/marco3_AAAAMMDD_HHMMSS.dump
```

**d) Conferência:** rodar de novo o `SELECT` do item (a) e voltar a ver **300 | 240**. Mostrar também que a segurança voltou:

```sql
SET ROLE a10000000001;  SELECT count(*) FROM tb_matricula;  RESET ROLE;   -- 3 (RLS restaurada)
```

## 3. Restaurar sem tocar no original (banco paralelo)

Útil para provar o backup sem risco:

```powershell
docker exec bd2_postgres bash /tmp/scripts/restaurar.sh /backup/marco3_AAAAMMDD_HHMMSS.dump marco3_restaurado
```

Cria `marco3_restaurado` (apagando-o antes, se existir), restaura e imprime a conferência
(`alunos=120 turmas=… matriculas=300 com_nota=240 policies=10 trigger_vagas=1`).

## 4. Recuperação total, do zero (servidor novo)

Simula perder tudo (inclusive o volume do Docker):

```powershell
docker compose down -v
docker compose up -d
# espere o Postgres ficar saudável (docker compose ps)
docker cp scripts bd2_postgres:/tmp/
docker cp ./backup/. bd2_postgres:/backup
docker exec bd2_postgres bash /tmp/scripts/restaurar.sh /backup/marco3_AAAAMMDD_HHMMSS.dump marco3 /backup/globais_AAAAMMDD_HHMMSS.sql
```

O terceiro argumento (`globais`) recria os papéis antes do `pg_restore`. Avisos `role "bd2" already exists` são esperados.
Depois, no pgAdmin, reconecte ao servidor e atualize a lista de bancos.

## 5. Limites (para a arguição)

- É backup **lógico**: uma fotografia do momento do `pg_dump` (consistente, pois o `pg_dump` usa uma única transação de snapshot, sem travar quem escreve).
  Tudo que acontecer **depois** dele se perde na restauração. Recuperação até um instante qualquer (*PITR*) exigiria arquivamento de WAL e `pg_basebackup`, que não fazem parte do escopo.
- Restaurar um dump de PostgreSQL 16 em um 17 funciona (para frente); o contrário, não.
- Em produção, o backup seria agendado (cron, `pgAgent`) e guardado fora da máquina, com teste periódico de restauração.

## 6. Problemas comuns

| Sintoma | Causa e solução |
|---|---|
| `bash: $'\r': command not found` ao rodar um `.sh` | O Git no Windows converteu as quebras de linha para CRLF. Já existe `.gitattributes` para evitar isso; para corrigir agora: `docker exec bd2_postgres sed -i 's/\r$//' /tmp/scripts/backup.sh /tmp/scripts/restaurar.sh /tmp/scripts/medir_concorrencia.sh` |
| `pg_restore: error: role "aluno" does not exist` | Faltou restaurar os papéis: passe o arquivo `globais_*.sql` como 3º argumento do `restaurar.sh` (§4) |
| `database "marco3" is being accessed by other users` | O pgAdmin está conectado. O `restaurar.sh` usa `DROP DATABASE ... WITH (FORCE)`; para um `DROP` manual, use o mesmo `WITH (FORCE)` |
