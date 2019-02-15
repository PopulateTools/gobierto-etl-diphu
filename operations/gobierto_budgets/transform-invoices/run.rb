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
#  - 0: Absolute path to a file with the input data
#  - 1: Absolute path of the output file
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/transform-invoices/run.rb input.csv output.json
#

if ARGV.length != 2
  raise "At least one argument is required"
end

input_file = ARGV[0]
output_file = ARGV[1]

puts "[START] transform-invoices/run.rb with file=#{input_file} output=#{output_file}"

base_attributes = {
  location_id: '21000DD000',
  province_id: nil,
  autonomous_region_id: nil,
  payment_date: nil,
  economic_budget_line_code: nil,
  functional_budget_line_code: nil
}

output_data = []
CSV::Converters[:strip] = lambda { |s| s.try(:strip) }
CSV.read(input_file, headers: true, encoding: 'utf-8', header_converters: lambda { |h| h.downcase.gsub(' ', '_') }, converters: [:strip]).each do |row|

  next if row["fecha_fac"].blank?

  begin
    m,d,y = row["fecha_fac"].split('/').map(&:to_i)
    date = Date.new(y,m,d)
  rescue
    puts row
    exit
  end
  # Ignore invoices older than 2017
  next if date.year < 2017

  attributes = {
    value: row['importe'].to_f,
    date: date.strftime("%Y-%m-%d"),
    invoice_id: [row['factura'], row['tercero'], row['fecha_fac']].join('/'),
    provider_id: row['tercero'],
    provider_name: row['nombre_ter.'],
    paid: true,
    subject: row['texto_libre'],
    freelance: row['tercero'] !~ /\A[A-Z]/i
  }

  output_data << attributes.merge(base_attributes)
end

File.write(output_file, output_data.to_json)

puts "[END] transform-invoices/run.rb output=#{output_file}"
