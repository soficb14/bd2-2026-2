#!/usr/bin/env bash
# =====================================================================
# BACKUP do banco do projeto (roda DENTRO do contêiner do Postgres).
#   docker cp scripts bd2_postgres:/tmp/
#   docker exec bd2_postgres bash /tmp/scripts/backup.sh
# Gera em /backup:
#   marco3_AAAAMMDD_HHMMSS.dump  - banco inteiro (formato custom, comprimido):
#                                  schema, dados, índices, views, policies, grants
#   globais_AAAAMMDD_HHMMSS.sql  - papéis (roles) do servidor: o pg_dump do
#                                  banco NÃO inclui papéis, pois são globais
# =====================================================================
set -euo pipefail
export PGUSER="${PGUSER:-bd2}"
BANCO="${BANCO:-marco3}"
DEST="${DEST:-/backup}"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$DEST"

pg_dump -Fc -d "$BANCO" -f "$DEST/${BANCO}_${TS}.dump"
pg_dumpall --globals-only -f "$DEST/globais_${TS}.sql"

# Verificação: o arquivo é legível e lista o conteúdo?
pg_restore -l "$DEST/${BANCO}_${TS}.dump" > /dev/null
echo "Backup OK:"
ls -lh "$DEST"/*"$TS"*
