#!/usr/bin/env bash
# =====================================================================
# Mede, com carga concorrente real (pgbench), as três situações da
# disputa por vagas: SEM proteção, com FOR UPDATE e com SERIALIZABLE.
#
# Roda DENTRO do contêiner do Postgres (lá já existem psql e pgbench):
#   docker cp scripts bd2_postgres:/tmp/
#   docker exec bd2_postgres bash /tmp/scripts/medir_concorrencia.sh
#
# Parâmetros opcionais (variáveis de ambiente):
#   RODADAS=10  CLIENTES=20  VAGAS=5  ESPERA=0.02
#   (cada rodada recria a turma CONC com VAGAS vagas e dispara CLIENTES
#    alunos ao mesmo tempo; ESPERA = segundos de "trabalho extra" da
#    transação antes do COMMIT, que alarga a janela da corrida)
# Pré-requisito: sql/08_concorrencia.sql já executado em marco3.
# =====================================================================
set -u
export PGUSER="${PGUSER:-bd2}" PGDATABASE="${PGDATABASE:-marco3}"
RODADAS="${RODADAS:-10}"; CLIENTES="${CLIENTES:-20}"; VAGAS="${VAGAS:-5}"; ESPERA="${ESPERA:-0.02}"
TMP="$(mktemp -d)"; Q="psql -v ON_ERROR_STOP=1 -q -At"

# --- função auxiliar do experimento (apagada no final) -----------------
$Q <<SQL
CREATE OR REPLACE FUNCTION academico.bench_tentar(p_aluno int, p_lock boolean, p_espera numeric)
RETURNS text LANGUAGE plpgsql SET search_path = academico, public AS \$\$
DECLARE v_turma int;
BEGIN
    SELECT id_turma INTO v_turma FROM tb_turma WHERE codigo = 'CONC';
    IF p_lock THEN
        PERFORM 1 FROM tb_turma WHERE id_turma = v_turma FOR UPDATE;   -- correção 1
    END IF;
    INSERT INTO tb_matricula (id_aluno, id_turma) VALUES (p_aluno, v_turma);  -- o trigger confere as vagas
    PERFORM pg_sleep(p_espera);                              -- trabalho extra antes do COMMIT
    RETURN 'OK';
EXCEPTION WHEN check_violation THEN
    RETURN 'SEM_VAGA';                                       -- o trigger recusou: turma cheia
END \$\$;
SQL

# --- os três scripts do pgbench ----------------------------------------
cat > "$TMP/sem.sql" <<EOF
\set aluno :client_id + 1
SELECT academico.bench_tentar(:aluno, false, $ESPERA);
EOF
cat > "$TMP/lock.sql" <<EOF
\set aluno :client_id + 1
SELECT academico.bench_tentar(:aluno, true, $ESPERA);
EOF
cat > "$TMP/ser.sql" <<EOF
\set aluno :client_id + 1
BEGIN ISOLATION LEVEL SERIALIZABLE;
SELECT academico.bench_tentar(:aluno, false, $ESPERA);
END;
EOF

printf '\n%-34s %10s %10s %12s %10s %12s\n' "MODO ($RODADAS rodadas, $CLIENTES clientes, $VAGAS vagas)" "matric." "estouro" "lat.media" "retries" "tempo total"
printf '%s\n' "------------------------------------------------------------------------------------------------"

medir () {  # $1=rótulo  $2=arquivo  $3=max-tries
    local tot_mat=0 tot_exc=0 tot_ret=0 lat_sum=0 t0 t1
    t0=$(date +%s.%N)
    for r in $(seq 1 "$RODADAS"); do
        $Q -c "SELECT academico.fn_reset_cenario_concorrencia($VAGAS)" >/dev/null
        out=$(pgbench -n -c "$CLIENTES" -j 4 -t 1 --max-tries="$3" -f "$TMP/$2" 2>&1)
        mat=$($Q -c "SELECT matriculados FROM academico.vw_conferencia_vagas WHERE turma='CONC'")
        exc=$($Q -c "SELECT excesso FROM academico.vw_conferencia_vagas WHERE turma='CONC'")
        ret=$(echo "$out" | awk '/total number of retries/ {print $NF}'); ret=${ret:-0}
        lat=$(echo "$out" | awk '/latency average/ {print $4}');        lat=${lat:-0}
        tot_mat=$((tot_mat+mat)); tot_exc=$((tot_exc+exc)); tot_ret=$((tot_ret+ret))
        lat_sum=$(awk -v a="$lat_sum" -v b="$lat" 'BEGIN{printf "%.6f", a+b}')
    done
    t1=$(date +%s.%N)
    printf '%-34s %10s %10s %9.1f ms %10s %10.1f s\n' "$1" "$tot_mat" "$tot_exc" \
        "$(awk -v a="$lat_sum" -v n="$RODADAS" 'BEGIN{printf "%.6f", a/n}')" "$tot_ret" "$(awk -v a="$t1" -v b="$t0" 'BEGIN{printf "%.6f", a-b}')"
}

medir "1) sem proteção (READ COMMITTED)" sem.sql 1
medir "2) FOR UPDATE (bloqueio explícito)" lock.sql 1
medir "3) SERIALIZABLE (com retentativa)" ser.sql 100

printf '\nLegenda: matric. = total de matrículas aceitas (o correto é %s x %s = %s);\n' "$RODADAS" "$VAGAS" "$((RODADAS*VAGAS))"
echo "estouro = matrículas ALÉM das vagas (anomalia); lat.media = latência média por transação;"
echo "retries = transações repetidas pelo pgbench após erro 40001 (só faz sentido em SERIALIZABLE)."

# --- limpeza ------------------------------------------------------------
$Q -c "DROP FUNCTION academico.bench_tentar(int, boolean, numeric)" >/dev/null
$Q -c "SELECT academico.fn_reset_cenario_concorrencia(1)" >/dev/null
rm -rf "$TMP"
