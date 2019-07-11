#!/bin/bash

# Some variables already defined in .env
source .env

GOBIERTO_ETL_UTILS=$BASE_DIR/gobierto-etl-utils
DIPHU_ETL=$BASE_DIR/gobierto-etl-diphu
WORKING_DIR=/tmp/diphu
DIPHU_INE_CODE=21000
URL=http://gobierto-data.s3.amazonaws.com/diphuelva/

rm -rf $WORKING_DIR
mkdir $WORKING_DIR

# Extract > Download data sources
cd $GOBIERTO_ETL_UTILS; ruby operations/download-s3/run.rb "diphuelva/invoices" $WORKING_DIR

# Extract > Check valid CSV
for file in $WORKING_DIR/*.csv; do
  cd $GOBIERTO_ETL_UTILS; ruby operations/check-csv/run.rb $file
done

# Transform > Transform planned budgets data files
for file in $WORKING_DIR/*.csv; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/transform-invoices/run.rb $file $file"_transformed.json"
done

# Load > Import invoices
for file in $WORKING_DIR/*_transformed.json; do
  cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/import-invoices/run.rb $file
done

echo $DIPHU_INE_CODE > $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb providers_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb
