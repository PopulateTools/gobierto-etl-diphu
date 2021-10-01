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
#  - 0: Absolute path to a JSON file
#  - 1: Site domain
#
# Samples:
#
#   /path/to/project/operations/gobierto_budgets/import-custom-categories/run.rb input.json domain.gobierto.es
#

if ARGV.length != 2
  raise "At least one argument is required"
end

input_file = ARGV[0]
INE_CODE = '21000'
kind = ARGV[0].include?('ingresos') ? GobiertoBudgetsData::GobiertoBudgets::INCOME : GobiertoBudgetsData::GobiertoBudgets::EXPENSE
SITE = Site.find_by! domain: ARGV[1]

puts "[START] import-custom-categories/run.rb with file=#{input_file} site=#{SITE.domain}"

def create_or_update_category!(name, code, kind)
  name_translations = { "es" => name }
  category_attrs = { site: SITE, area_name: GobiertoBudgetsData::GobiertoBudgets::CUSTOM_AREA_NAME, kind: kind,
                     code: code }

  if (category = GobiertoBudgets::Category.where(category_attrs).first)
    category.update_attributes!(custom_name_translations: name_translations)
    puts "- Updated category #{name} (code = #{code}, kind = #{kind})"
  else
    GobiertoBudgets::Category.create!(
      category_attrs.merge(custom_name_translations: name_translations)
    )
    puts "- Created category #{name} (code = #{code}, kind = #{kind})"
  end
end

JSON.parse(File.read(input_file)).each do |row|
  create_or_update_category!(row["name"], row["code"], row["kind"])
end

puts "[END] import-custom-categories/run.rb"
