#!/usr/bin/env bash
# =====================================================================
# RESTAURAÇÃO (roda DENTRO do contêiner do Postgres).
#   docker exec bd2_postgres bash /tmp/scripts/restaurar.sh /backup/marco3_XXXX.dump [banco_destino] [globais.sql]
#
# - banco_destino (padrão: marco3_restaurado) é APAGADO e recriado.
# - globais.sql (opcional): só necessário num servidor NOVO, onde os papéis
#   ainda não existem (aluno, secretaria, coordenacao...). Os avisos
#   "role ... already exists" ao aplicá-lo são esperados e inofensivos.
# =====================================================================
set -euo pipefail
export PGUSER="${PGUSER:-bd2}"
DUMP="${1:?informe o arquivo .dump}"
DESTINO="${2:-marco3_restaurado}"
GLOBAIS="${3:-}"

if [ -n "$GLOBAIS" ]; then
    echo ">> Restaurando papéis globais ($GLOBAIS)"
    psql -d postgres -q -f "$GLOBAIS" 2>&1 | grep -v "already exists" || true
fi

echo ">> Recriando o banco $DESTINO"
psql -d postgres -q -c "DROP DATABASE IF EXISTS \"$DESTINO\" WITH (FORCE)"
psql -d postgres -q -c "CREATE DATABASE \"$DESTINO\" TEMPLATE template0"

echo ">> pg_restore"
pg_restore -d "$DESTINO" --no-owner --exit-on-error "$DUMP"

echo ">> Conferência"
psql -d "$DESTINO" -At -c "SET search_path TO academico;
SELECT 'alunos='||(SELECT count(*) FROM tb_aluno)||' turmas='||(SELECT count(*) FROM tb_turma)
    ||' matriculas='||(SELECT count(*) FROM tb_matricula)||' com_nota='||(SELECT count(*) FROM tb_historico WHERE media_geral IS NOT NULL)
    ||' policies='||(SELECT count(*) FROM pg_policies WHERE schemaname='academico')
    ||' trigger_vagas='||(SELECT count(*) FROM pg_trigger WHERE tgname='tg_valida_vaga');"
