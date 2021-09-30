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

nitems = GobiertoBudgetsData::GobiertoBudgets::BudgetLinesImporter.new(index: index, year: year,
                                                                       data: JSON.parse(File.read(data_file))).import!

puts "[END] import-budgets/run.rb imported #{nitems} items"
