#!/bin/bash

FOLDER="licitaciones"
PATH="$HOME/.rbenv/shims:$PATH"
ETL_UTILS="/home/populate/gobierto-etl-utils"
ETL="/home/populate/gobierto-etl-diphu"
DATASET_NAME="Licitaciones"
DATASET_SLUG="licitaciones"
DATASET_TABLE_NAME="${FOLDER}"
DIPHU_CODE="21041"
GOBIERTO_DATA_DEST_URL="https://des-presupuestos.diphuelva.es"
GOBIERTO_DATA_SOURCE_URL="https://datos.gobierto.es"

source ${ETL}/.rbenv-vars;
cd ${ETL_UTILS};
QUERY=`sed "s/<PLACE_ID>/${DIPHU_CODE}/g" ${ETL_UTILS}/operations/gobierto_data/extract-contracts/query.sql | jq -s -R -r @uri`
FILEURL=$GOBIERTO_DATA_SOURCE_URL"/api/v1/data/data.csv?token="$READ_API_TOKEN"&sql="$QUERY

ruby operations/gobierto_data/upload-dataset/run.rb \
  --api-token $WRITE_API_TOKEN \
  --name "$DATASET_NAME" \
  --slug $DATASET_SLUG \
  --table-name $DATASET_TABLE_NAME \
  --gobierto-url $GOBIERTO_DATA_DEST_URL \
  --schema-path ${ETL_UTILS}/operations/gobierto_data/extract-contracts/schema.json \
  --file-url $FILEURL \
  --no-verify-ssl
