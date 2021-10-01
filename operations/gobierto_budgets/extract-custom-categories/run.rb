#!/usr/bin/env ruby

require "bundler/setup"
Bundler.require

require "json"
require "csv"

# Usage:
#
#  - Must be ran as an independent Ruby script
#
# Arguments:
#
#  - 0: Absolute path to a file containing a CSV or a Excel file
#  - 1: Custom categories mapping file
#  - 2: JSON output path
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/extract-custom-categories/run.rb input.csv output.json custom_categories_mapping_2021.csv
#

if ARGV.length != 3
  raise "At least one argument is required"
end

input_file = ARGV[0]
csv_mappings = CSV.read(ARGV[1], headers: true)
output_file = ARGV[2]
kind = GobiertoBudgetsData::GobiertoBudgets::EXPENSE

puts "[START] extract-custom-categories/run.rb with file=#{input_file} and mapping_file=#{ARGV[1]}"

def process_row(row, kind, output)
  name = row[3]
  custom_code = [row[0], row[1], row[2]].join("-")

  output.push({name: name, code: custom_code, kind: kind})
  output
end

def process_mapping_row(row, kind, output)
  name = row[1]
  custom_code = row[2].to_i.to_s #remove 0s

  output.push({name: name, code: custom_code, kind: kind}) unless output.find{ |r| r[:code] == custom_code }
  output
end

data = if input_file.include?(".csv")
  CSV.read(input_file, headers: true, encoding: 'utf-8')
else
  xls = Roo::Spreadsheet.open(input_file, extension: :xls)
  sheet = xls.sheet(0)

  rows = []
  sheet.each_with_index do |row, idx|
    next if idx == 0
    rows.push(row.map{ |i| i.is_a?(String) ? i.encode('UTF-8').force_encoding('UTF-8') : i })
  end
  rows
end

output = []

if File.exists?(output_file)
  existing_output = JSON.parse(File.read(output_file))
else
  existing_output = []
end

output = existing_output.concat(output)

data.each do |row|
  output = process_row(row, kind, output)
end

csv_mappings.each do |row|
  output = process_mapping_row(row, kind, output)
end
# TODO: remove when all mappings are completed
output.push({name: 'OTRAS', code: 9, kind: kind})

File.write(output_file, output.to_json)

puts "[END] extract-custom-categories/run.rb"
