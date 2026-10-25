#!/usr/bin/env bash
# Put this file and both SQL16 files in the same directory on EC2, then run with bash.
set -euo pipefail
umask 077
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
db_name=KLCN021_HealthBeauty
container=sqlserver
target_dir=/tmp/healthbeauty-sepay-schema16
test -s "$script_dir/16_BankTransfers.sql"
test -s "$script_dir/16_VerifyBankTransfers.sql"
before_id=$(sudo docker inspect "$container" --format '{{.Id}}')
test "$(sudo docker inspect "$container" --format '{{.State.Running}}')" = true

sudo docker exec "$container" mkdir -p "$target_dir"
sudo docker cp "$script_dir/16_BankTransfers.sql" "$container:$target_dir/16_BankTransfers.sql"
sudo docker cp "$script_dir/16_VerifyBankTransfers.sql" "$container:$target_dir/16_VerifyBankTransfers.sql"

run_sql_file() {
  sudo docker exec "$container" sh -c '
    set -eu
    sqlcmd_bin=/opt/mssql-tools18/bin/sqlcmd
    test -x "$sqlcmd_bin" || sqlcmd_bin=/opt/mssql-tools/bin/sqlcmd
    test -x "$sqlcmd_bin" || { echo "sqlcmd is not installed in the SQL Server container." >&2; exit 1; }
    sql_password=${MSSQL_SA_PASSWORD:-${SA_PASSWORD:-}}
    test -n "$sql_password" || { echo "No SA password variable is available. Use your existing administrative SQL connection instead." >&2; exit 1; }
    export SQLCMDPASSWORD="$sql_password"
    exec "$sqlcmd_bin" -S localhost -U sa -C -d "$1" -b -r 1 -i "$2"
  ' sh "$db_name" "$1"
}

echo "Applying SQL16 to database $db_name in container $container. No API/SQL container restart is performed."
run_sql_file "$target_dir/16_BankTransfers.sql"
run_sql_file "$target_dir/16_VerifyBankTransfers.sql"
test "$(sudo docker inspect "$container" --format '{{.Id}}')" = "$before_id"
echo 'PASS: SQL16 and read-only verification completed; SQL container identity is unchanged.'
