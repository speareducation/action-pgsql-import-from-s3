#!/usr/bin/env bash

apk add postgresql-bdr-client

INITIAL_DIR=$(pwd)

[ -z "$INPUT_DATABASES" ] && echo '$INPUT_DATABASES Not set' && exit 1

S3_IMPORTS_DIR=/tmp/.pgsql-import-from-s3
mkdir -p ${S3_IMPORTS_DIR}
cd ${S3_IMPORTS_DIR}

[ ! -z "$INPUT_POSTGRES_PASS" ] && export PGPASSWORD=$INPUT_POSTGRES_PASS

POSTGRES="psql --host $INPUT_POSTGRES_HOST --port $INPUT_POSTGRES_PORT --username $INPUT_POSTGRES_USER "

for dbName in $INPUT_DATABASES
do
    tddDbName="${dbName}_tdd"
    dumpFile="./$dbName.sql.gz"

    echo "Downloading schema dump for $dbName"

    S3_LOCATION="s3://$INPUT_S3_BUCKET/redshift/schemas/$dbName.schema.latest.sql.gz
    echo "Trying ${S3_LOCATION}" && \
    aws s3 cp "${S3_LOCATION}" "$dumpFile"

    [[ ! -f "$dumpFile" ]] && echo "Failed to download $dumpFile" && exit 1

    echo "Creating $tddDbName"
    echo "Creating schema $db"
    $POSTGRES -d $tddDbName -e "CREATE SCHEMA IF NOT EXISTS $tddDbName;" || exit 1

    echo "Importing $tddDbName from file '${dumpFile}'"
    if [[ "$dumpFile" == *.gz ]]
    then
        gunzip -c "$dumpFile"
        dumpFile=$(echo $dumpFile | sed -e 's/.gz$//g')
    fi
    $POSTGRES -d $tddDbName -f $dumpFile --echo-errors -t || exit 254

done

echo "Cleaning up imports dir ${S3_IMPORTS_DIR}..."
rm -rf ${S3_IMPORTS_DIR}

exit 0