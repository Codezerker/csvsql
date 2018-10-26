# frozen_string_literal: true

require "csvsql/version"

require 'csv'
require 'sqlite3'
require 'digest'
require 'fileutils'

require 'csvsql/db'
require 'csvsql/tracker'
require 'csvsql/command_runner'

module Csvsql
  extend self

  CACHE_DIR = File.join(Dir.home, '.csvsql_cache')
  FileUtils.mkdir_p(CACHE_DIR) unless Dir.exists?(CACHE_DIR)

  def execute(sql, csv_data, opts = {})
    csvdb = init_data(csv_data, opts)
    pst = Csvsql::Tracker.commit(:execute_query_sql) do
      csvdb.prepare(sql)
    end
    Csvsql::Tracker.commit(:output_format)
    CSV.generate do |csv|
      csv << pst.columns.zip(pst.types).map { |c| c.compact.join(':') }
      pst.each { |line| csv << line }
    end.tap { Csvsql::Tracker.commit(:output_format) }
  end

  def self.clear_cache!
    FileUtils.rm_f(Dir.glob(File.join(CACHE_DIR, '*')))
  end

  private

  def init_data(csv_data, opts)
    encoding = opts.delete(:encoding)
    use_cache = opts.delete(:use_cache)
    csvdb = Csvsql::Db.new(opts)

    unless use_cache
      csvdb.import(csv_data, encoding: encoding)
      return csvdb
    end

    case csv_data
    when StringIO, IO
      # nothing
    when Hash
      dbs = []
      csv_data.each do |dbname, csv_path|
        dbs << [dbname, csvdb.init_db(get_db_cache_path(csv_path) || '')]
        csvdb.import(csv_path, encoding: encoding)
      end
      dbs.each do |dbname, db|
        csvdb.execute("ATTACH DATABASE '#{db.filename}' AS #{dbname};")
      end
    else
      csvdb.init_db(get_db_cache_path(csv_data) || '')
      csvdb.import(csv_data, encoding: encoding)
    end

    csvdb
  end

  def get_db_cache_path(csv_path)
    csv_path = csv_path || ''
    return unless File.exist?(csv_path)

    stat = File.stat(csv_path)
    filename = Digest::SHA2.hexdigest(File.absolute_path(csv_path)) + '.cache'
    file_stat = [File.absolute_path(csv_path), stat.size, stat.ctime].join("\n")
    stat_path = File.join(CACHE_DIR, filename.gsub(/\.cache$/, '.stat'))
    cache_path = File.join(CACHE_DIR, filename)

    if File.exist?(stat_path)
      if File.read(stat_path) == file_stat
        cache_path
      else
        if update_cb
          update_cb.call
        else
          FileUtils.rm(cache_path)
        end
        File.write(stat_path, file_stat)
        cache_path
      end
    else
      File.write(stat_path, file_stat)
      cache_path
    end
  end
end
