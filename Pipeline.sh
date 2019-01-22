#!/bin/bash

# Some variables already defined in .env
source .env

GOBIERTO_ETL_UTILS=$BASE_DIR/gobierto-etl-utils
DIPHU_ETL=$BASE_DIR/gobierto-etl-diphu
GOBIERTO=$BASE_DIR/gobierto
WORKING_DIR=/tmp/diphu
DIPHU_INE_CODE=21000DD000
YEARS="2019 2018 2017 2016 2015"
URL=http://gobierto-data.s3.amazonaws.com/diphuelva/

rm -rf $WORKING_DIR
mkdir $WORKING_DIR

# Extract > Download data sources
cd $GOBIERTO_ETL_UTILS; ruby operations/download-s3/run.rb "diphuelva/budgets" $WORKING_DIR

# Extract > Check valid CSV
for file in $WORKING_DIR/*.csv; do
  cd $GOBIERTO_ETL_UTILS; ruby operations/check-csv/run.rb $file
done

# Transform > Transform planned budgets data files
for file in $WORKING_DIR/*.csv; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/transform-planned/run.rb $file $file"_transformed.json"
done

for file in $WORKING_DIR/*_transformed.json; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/import-planned-budgets/run.rb $file
done

# Load > Calculate totals
echo $DIPHU_INE_CODE > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb $YEARS $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb  $YEARS $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb
