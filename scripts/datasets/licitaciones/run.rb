#!/usr/bin/env ruby

require 'uri'
require "bundler/setup"
Bundler.require

require_relative '../../../lib/gobierto_data/client'

DIPHU_CODE = "21041"
ETL_UTILS="/home/populate/gobierto-etl-utils"
GOBIERTO_DATA_DEST_URL= "https://des-presupuestos.diphuelva.es"
GOBIERTO_DATA_SOURCE_URL= "https://datos.gobierto.es"
DATASET_NAME = "Licitaciones"
DATASET_SLUG = "licitaciones"
DATASET_TABLE_NAME = "licitaciones"

raw_query_source = File.read File.join(ETL_UTILS, "operations", "gobierto_data", "extract-tenders", "query.sql")
query = raw_query_source.gsub("<PLACE_ID>", DIPHU_CODE)
query = query.gsub("\n", ' ').gsub(/\s{1,}/, '+').strip
file_url = URI::join(GOBIERTO_DATA_SOURCE_URL, "/api/v1/data/data.csv?token=#{ENV.fetch('READ_API_TOKEN')}&sql=#{query}").to_s

options = {
  api_token: ENV.fetch('WRITE_API_TOKEN'),
  gobierto_url: GOBIERTO_DATA_DEST_URL,
  debug: true,
  no_verify_ssl: true,
  name: DATASET_NAME,
  slug: DATASET_SLUG,
  table_name: DATASET_TABLE_NAME,
  schema_path: File.join(ETL_UTILS, "/operations/gobierto_data/extract-tenders/schema.json"),
  file_url: file_url,
  visibility_level: 'active'
}

gobierto_data_client = GobiertoData::Client.new(options.slice(:api_token, :gobierto_url, :debug, :no_verify_ssl))
gobierto_data_client.upsert_dataset(options.except(:api_token, :gobierto_url, :debug))
