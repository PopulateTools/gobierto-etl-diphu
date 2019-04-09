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
#  - 0: Absolute path to a file containing a CSV downloaded from Sant Feliu data source
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
kind = ARGV[0].include?("income") ? GobiertoData::GobiertoBudgets::INCOME : GobiertoData::GobiertoBudgets::EXPENSE
year = ARGV[0].match(/\d+/)[0].to_i
execution = input_file.include?("execution")

puts "[START] transform-budgets/run.rb with file=#{input_file} output=#{output_file} year=#{year}"

csv_data = CSV.read(input_file, headers: true, encoding: 'utf-8')

base_data = {
  organization_id: '21000DD000',
  ine_code: nil,
  province_id: nil,
  autonomy_id: nil,
  year: year,
  population: nil
}

def normalize_data(data, kind, execution)
  functional_data = {}
  economic_data = {}

  data.each do |row|
    functional_data, economic_data = process_row(row, functional_data, economic_data, kind, execution)
  end

  return functional_data, economic_data
end

def process_row(row, functional_data, economic_data, kind, execution)
  income = kind == GobiertoData::GobiertoBudgets::INCOME
  amount = if execution
             income ? row[6].to_f : row[7].to_f
           else
             income ? row[3].to_f : row[4].to_f
           end
  amount = amount.round(2)
  functional_code = income ? nil : row[1]
  economic_code   = income ? row[1] : row[2]

  # Level 3
  economic_code_l3 = economic_code[0..2]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l3 = functional_code[0..2]
    functional_data[functional_code_l3] ? functional_data[functional_code_l3] += amount : functional_data[functional_code_l3] = amount
  end
  economic_data[economic_code_l3] ? economic_data[economic_code_l3] += amount : economic_data[economic_code_l3] = amount

  # Level 2
  economic_code_l2 = economic_code[0..1]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l2 = functional_code[0..1]
    functional_data[functional_code_l2] ? functional_data[functional_code_l2] += amount : functional_data[functional_code_l2] = amount
  end
  economic_data[economic_code_l2] ? economic_data[economic_code_l2] += amount : economic_data[economic_code_l2] = amount

  # Level 1
  economic_code_l1 = economic_code[0]
  if kind == GobiertoData::GobiertoBudgets::EXPENSE
    functional_code_l1 = functional_code[0]
    functional_data[functional_code_l1] ? functional_data[functional_code_l1] += amount : functional_data[functional_code_l1] = amount
  end
  economic_data[economic_code_l1] ? economic_data[economic_code_l1] += amount : economic_data[economic_code_l1] = amount

  return functional_data, economic_data
end

def hydratate(options)
  area_name = options.fetch(:area_name)
  data      = options.fetch(:data)
  base_data = options.fetch(:base_data)
  kind      = options.fetch(:kind)

  data.map do |code, amount|
    code = code.to_s
    level = code.length == 6 ? 4 : code.length
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


functional_data, economic_data = normalize_data(csv_data, kind, execution)

output_data = hydratate(data: functional_data, area_name: GobiertoData::GobiertoBudgets::FUNCTIONAL_AREA_NAME, base_data: base_data, kind: kind) +
  hydratate(data: economic_data, area_name: GobiertoData::GobiertoBudgets::ECONOMIC_AREA_NAME, base_data: base_data, kind: kind)

File.write(output_file, output_data.to_json)

puts "[END] transform-budgets/run.rb output=#{output_file}"