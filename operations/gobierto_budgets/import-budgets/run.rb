#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

data_file = ARGV[0]
year = ARGV[0].match(/\/(\d{4})/)[1].to_i
index = if data_file.include?("ejecucion")
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_EXECUTED
        else
          GobiertoBudgetsData::GobiertoBudgets::ES_INDEX_FORECAST
        end

puts "[START] import-budgets/run.rb year=#{year} data_file=#{data_file} index=#{index}"

## nitems = GobiertoBudgetsData::GobiertoBudgets::BudgetLinesImporter.new(index: index, year: year,
##                                                                        data: JSON.parse(File.read(data_file))).import!

headers = %W(
year
code
area
kind
initial_value
modified_value
executed_value
organization_id
functional_code
custom_code
ID
level
parent_code
)

data = JSON.parse(File.read(data_file))

###
# {
#  "organization_id"=>"21000", "ine_code"=>nil, "province_id"=>nil, "autonomy_id"=>nil, "year"=>2021,
#  "population"=>nil, "amount"=>1080498.67, "code"=>"100", "level"=>3, "kind"=>"G",
#  "amount_per_inhabitant"=>nil, "parent_code"=>"10", "type"=>"economic"
#  }
###

output_file = if data_file.include?("2021-gastos.csv_transformed.json")
                "2021-gastos-sample.csv"
              else
                "2021-ingresos-sample.csv"
              end

CSV.open("/tmp/diphu/#{output_file}", "wb+") do |csv|
  csv << headers
  data.each do |data_row|
    row = []
    row << 2021
    row << data_row["code"]
    row << data_row["type"]
    row << data_row["kind"] == "G" ? "E" : "I"
    row << data_row["amount"]
    row << data_row["amount_updated"]
    row << data_row["amount_executed"]
    row << data_row["organization_id"]
    row << ""
    row << ""
    row << ""
    row << data_row["level"]
    row << data_row["parent_code"]
    csv << row
  end
end

