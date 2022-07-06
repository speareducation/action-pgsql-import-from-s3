#!/usr/bin/env bash

INITIAL_DIR=$(pwd)

[ -z "$INPUT_DATABASES" ] && echo '$INPUT_DATABASES Not set' && exit 1

mkdir .pgsql-import-from-s3 && cd .pgsql-import-from-s3

echo "
[mysql]
user = $INPUT_POSTGRES_USER
host = $INPUT_POSTGRES_HOST
" > .my.cnf

[ ! -z "$INPUT_POSTGRES_PASS" ] && export PGPASSWORD=$INPUT_POSTGRES_PASS
[ ! -z "$INPUT_POSTGRES_PORT" ] && port = $INPUT_POSTGRES_PORT

POSTGRES="psql --host $host --port $port --username $user "

# Wait for MySQL to start"
i=0; while [ $((i+1)) -lt 30 ] && [ ! $($POSTGRES -Nse "SELECT VERSION();") ]
do
    echo "Waiting for MySQL... $i"
    sleep 1;
done
[ "$i" == "30" ] && echo "Failed to connect to mysql." && exit 1

for ENTRY in $(echo "$INPUT_DATABASES" | jq -c .[])
do
    db=$(echo "$ENTRY" | jq -r .db)
    s3Uri=$(echo "$ENTRY" | jq -r .s3Uri)
    dumpFile=$(basename "$s3Uri")
    aws s3 cp "$s3Uri" "./$dumpFile"
    [ ! -f "$dumpFile" ] && echo "Failed to download $dumpFile" && exit 1

    echo "Creating schema $db"
    $POSTGRES -d $db -e "CREATE SCHEMA IF NOT EXISTS $db;" || exit 1
    
    echo "Importing $db from file '${dumpFile}'"
    if [[ "$dumpFile" == *.gz ]]
    then
        gunzip -c "$dumpFile"
        dumpFile=$(echo $dumpFile | sed -e 's/.gz$//g')
    fi
    $POSTGRES -d $db -f $dumpFile --echo-errors -t || exit 254
done
echo "Cleaning up .mysql-import-from-s3 dir..."
rm -rf .pgsql-import-from-s3
exit 0
