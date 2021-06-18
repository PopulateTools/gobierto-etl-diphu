#!/bin/bash

set -e

# Some variables already defined in .env
source .env

WORKING_DIR=/tmp/diphu
DIPHU_INE_CODE=21000
YEARS="2021 2020 2019 2018 2017"
CURRENT_YEAR_CUSTOM_BUDGETS=$DATA_DIR/presupuestos/2021-gastos.csv
MAPPINGS_FILE=$DATA_DIR/custom_categories_mapping_2021.csv

rm -rf $WORKING_DIR
mkdir -p $WORKING_DIR/presupuestos

# Extract > Create organization id
echo $DIPHU_INE_CODE > $WORKING_DIR/organization.id.txt

# Extract > Copy data to WORKING_DIR
cp -R $DATA_DIR/* $WORKING_DIR/

# Extract > Extract custom categories
cd $DIPHU_ETL; ruby $DIPHU_ETL/operations/gobierto_budgets/extract-custom-categories/run.rb $CURRENT_YEAR_CUSTOM_BUDGETS $MAPPINGS_FILE $WORKING_DIR/custom_categories.json

# Transform > Transform budgets data files
for file in $WORKING_DIR/presupuestos/*; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/transform-budgets/run.rb $file $file"_transformed.json" $MAPPINGS_FILE
done

# Load > Clear previous budgets
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/clear-budgets/run.rb $WORKING_DIR/organization.id.txt

# Load > Import transformed data
for file in $WORKING_DIR/presupuestos/*_transformed.json; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/import-budgets/run.rb $file
done

# Load > Import custom categories
cd $GOBIERTO_DIR; bin/rails runner $DIPHU_ETL/operations/gobierto_budgets/import-custom-categories/run.rb $WORKING_DIR/custom_categories.json $GOBIERTO_DOMAIN

# Load > Calculate totals
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/update_total_budget/run.rb "$YEARS" $WORKING_DIR/organization.id.txt

# Load > Calculate bubbles
cd $GOBIERTO_ETL_UTILS; ruby operations/gobierto_budgets/bubbles/run.rb $WORKING_DIR/organization.id.txt

# Load > Calculate annual data
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto_budgets/annual_data/run.rb  "$YEARS" $WORKING_DIR/organization.id.txt

# Load > Publish activity
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/publish-activity/run.rb budgets_updated $WORKING_DIR/organization.id.txt

# Clear cache
cd $GOBIERTO_DIR; bin/rails runner $GOBIERTO_ETL_UTILS/operations/gobierto/clear-cache/run.rb
