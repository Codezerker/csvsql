# frozen_string_literal: true

require "csvsql/version"

require 'csv'
require 'sqlite3'

require 'csvsql/db'
require 'csvsql/tracker'

module Csvsql
  def self.execute(sql, csv_data, opts = {})
    encoding = opts.delete(:encoding)
    csvdb = Csvsql::Db.new(opts)
    csvdb.import(csv_data, encoding: encoding)
    pst = Csvsql::Tracker.commit(:execute_query_sql) do
      csvdb.prepare(sql)
    end
    Csvsql::Tracker.commit(:output_format)
    CSV.generate do |csv|
      csv << pst.columns.zip(pst.types).map { |c| c.compact.join(':') }
      pst.each { |line| csv << line }
    end.tap { Csvsql::Tracker.commit(:output_format) }
  end
end
