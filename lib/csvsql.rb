require "csvsql/version"

require 'csv'
require 'sqlite3'
require 'pry'

require 'csvsql/db'

module Csvsql
  def self.execute(sql, csv_path)
    csvdb = Csvsql::Db.new
    csvdb.import(csv_path)
    CSV.generate do |csv|
      csv << csvdb.header.map { |h| h.join(':') }
      csvdb.execute(sql).each { |line| csv << line }
    end
  end
end
