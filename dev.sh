#!/bin/bash

set -e

# Some variables already defined in .env
source .env

WORKING_DIR=/tmp/diphu
DIPHU_INE_CODE=21000
YEARS="2021"
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

# Load > Import transformed data
for file in $WORKING_DIR/presupuestos/*_transformed.json; do
  cd $DIPHU_ETL; ruby operations/gobierto_budgets/import-budgets/run.rb $file
done
