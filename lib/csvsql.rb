# frozen_string_literal: true

require "csvsql/version"

require 'csv'
require 'sqlite3'

require 'csvsql/db'

module Csvsql
  def self.execute(sql, csv_data, opts = {})
    csvdb = Csvsql::Db.new(opts)
    csvdb.import(csv_data)
    pst = csvdb.prepare(sql)
    CSV.generate do |csv|
      csv << pst.columns.zip(pst.types).map { |c| c.compact.join(':') }
      pst.each { |line| csv << line }
    end
  end
end
