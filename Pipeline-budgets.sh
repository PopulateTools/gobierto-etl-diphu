#!/bin/bash

set -e

# Some variables already defined in .env
source .env

GOBIERTO_ETL_UTILS=$BASE_DIR/gobierto-etl-utils
DIPHU_ETL=$BASE_DIR/gobierto-etl-diphu
WORKING_DIR=/tmp/diphu
DIPHU_INE_CODE=21000
YEARS="2019 2018 2017 2016 2015"

rm -rf $WORKING_DIR
mkdir $WORKING_DIR

#TODO Remove
echo $DIPHU_INE_CODE > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/clear-budgets/run.rb $WORKING_DIR/organization.id.txt

# Copy data to WORKING_DIR
cp -R $DATA_DIR $WORKING_DIR

# Extract > Extract custom categories
for file in $WORKING_DIR/presupuestos/*; do
  cd $DIPHU_ETL; ruby $DIPHU_ETL/operations/gobierto_budgets/extract-custom-categories/run.rb $file $WORKING_DIR/custom_categories.json
done

# Load > Import custom categories
cd $GOBIERTO_DIR; bin/rails runner $DIPHU_ETL/operations/gobierto_budgets/import-custom-categories/run.rb $WORKING_DIR/custom_categories.json $GOBIERTO_DOMAIN

# Transform > Transform budgets data files
for file in $WORKING_DIR/presupuestos/*; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/transform-budgets/run.rb $file $file"_transformed.json"
done

# Load > Import transformed data
for file in $WORKING_DIR/presupuestos/*_transformed.json; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/import-budgets/run.rb $file
done

# Load > Calculate totals
echo $DIPHU_INE_CODE > $WORKING_DIR/organization.id.txt
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb "$YEARS" $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb  "$YEARS" $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb
