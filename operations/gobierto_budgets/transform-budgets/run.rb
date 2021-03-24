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
#  - 1: Absolute path of the output file
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-budgets/run.rb input.csv output.json
#

if ARGV.length != 2
  raise "At least one argument is required"
end

input_file = ARGV[0]
output_file = ARGV[1]
@kind = ARGV[0].include?("ingresos") ? GobiertoData::GobiertoBudgets::INCOME : GobiertoData::GobiertoBudgets::EXPENSE
year = ARGV[0].match(/(\d{4})/)[1].to_i
execution = input_file.include?("ejecucion")

puts "[START] transform-budgets/run.rb with file=#{input_file} output=#{output_file} year=#{year}"

def transformed_data
  @transformed_data ||= indexes.inject({}) do |indexes_result, index|
    indexes_result.update(
      index => areas.inject({}) do |areas_result, area|
        areas_result.update(
          area => {}
        )
      end
    )
  end
end

def kind
  @kind
end

def indexes
  @indexes ||= [
    GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST
  ]
end

def areas
  @areas ||= [
    GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME,
    GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME,
    GobiertoData::GobiertoBudgets::CUSTOM_AREA_NAME
  ]
end

def areas_with_levels
  @areas_with_levels ||= areas - [GobiertoData::GobiertoBudgets::CUSTOM_AREA_NAME]
end

def normalize_data(data)
  data.each do |row|
    process_row(row)
  end
end

def parse_amount(s)
  raise "Nil value!" if s.blank?
  s.tr(',', '').to_f.round(2)
end

def process_row(row)
  income = kind == GobiertoData::GobiertoBudgets::INCOME
  amounts = {
    GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST => parse_amount(income ? row[3] : row[4])
  }
  codes = {
    GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME => income ? row[1] : row[2],
    GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME => income ? nil : row[1],
    GobiertoData::GobiertoBudgets::CUSTOM_AREA_NAME => income ? [row[0], row[1]].join("-") : [row[0], row[1], row[2]].join("-")
  }

  return if codes[GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME].nil?

  indexes.each do |index|
    areas.each do |area|
      next if (code = codes[area]).nil?

      if areas_with_levels.include?(area)
        code_levels = [code[0..2], code[0..1], code[0]]
        code_levels.each do |code_level|
          transformed_data[index][area][code_level] = transformed_data[index][area].fetch(code_level, 0) + amounts[index]
        end
      else
        transformed_data[index][area][code] = amounts[index]
      end
    end
  end
end

def hydratate(options)
  area_name = options.fetch(:area_name)
  data      = options.fetch(:data)
  base_data = options.fetch(:base_data)
  kind      = options.fetch(:kind)

  data.compact.map do |code, amount|
    code = code.to_s
    level = code.length == 6 ? 4 : code.length
    if area_name == GobiertoData::GobiertoBudgets::CUSTOM_AREA_NAME
      level = 1
    end
    parent_code = case level
                    when 1
                      nil
                    when 4
                      code[0..2]
                    else
                      code[0..-2]
                    end

    base_data.merge(amount: amount.round(2), code: code, level: level, kind: kind,
                    amount_per_inhabitant: base_data[:population] ? (amount / base_data[:population]).round(2) : nil,
                    parent_code: parent_code, type: area_name)
  end
end

base_data = {
  organization_id: '21000',
  ine_code: nil,
  province_id: nil,
  autonomy_id: nil,
  year: year,
  population: nil
}

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

normalize_data(data)

output_files = {
  GobiertoData::GobiertoBudgets::ES_INDEX_FORECAST => output_file
}

output_files.each do |index, file_name|
  output_data = areas.inject([]) do |aggregated_data, area|
    aggregated_data + hydratate(data: transformed_data[index][area],
                                area_name: area,
                                base_data: base_data,
                                kind: kind)
  end
  File.write(file_name, output_data.to_json)
end

puts "[END] transform-budgets/run.rb output=#{output_file}"
