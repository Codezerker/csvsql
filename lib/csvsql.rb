# frozen_string_literal: true

require "csvsql/version"

require 'csv'
require 'sqlite3'

require 'csvsql/db'

module Csvsql
  def self.execute(sql, csv_path)
    csvdb = Csvsql::Db.new
    csvdb.import(csv_path)
    pst = csvdb.prepare(sql)
    CSV.generate do |csv|
      csv << pst.columns.zip(pst.types).map { |c| c.join(':') }
      pst.each { |line| csv << line }
    end
  end
end
