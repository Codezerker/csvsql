# frozen_string_literal: true

require 'digest'

module Csvsql
  class Db
    BATCH_LINES = 10000
    CACHE_DIR = File.join(Dir.home, '.csvsql_cache')

    FileUtils.mkdir_p(CACHE_DIR) unless Dir.exists?(CACHE_DIR)

    attr_reader :use_cache, :csv_path, :csv_io, :db

    def self.clear_cache!
      require 'fileutils'
      FileUtils.rm_f(Dir.glob(File.join(CACHE_DIR, '*')))
    end

    def initialize(use_cache: false)
      @db = nil
      @csv_path = nil
      @use_cache = use_cache
    end

    # action:
    #   raise: default
    #   exit
    def sql_error_action=(action)
      @sql_error_action = action.to_sym
    end

    def execute(sql)
      db.execute(sql)
    rescue SQLite3::SQLException => e
      process_sql_error(sql, e)
    end

    def prepare(sql)
      db.prepare(sql)
    rescue SQLite3::SQLException => e
      process_sql_error(sql, e)
    end

    def import(csv_data_or_path)
      case csv_data_or_path
      when StringIO, IO
        @csv_io = csv_data_or_path
      else
        @csv_path = csv_data_or_path
      end
      @db = SQLite3::Database.new(get_db_path(@csv_path))

      tables = db.execute("SELECT name FROM sqlite_master WHERE type='table';").first
      unless tables && tables.include?('csv')
        init_db_by_csv(@csv_io ? CSV.new(@csv_io) : CSV.open(@csv_path))
      end
      true
    end

    private

    def parser_header(csv_header)
      csv_header.map do |col, r|
        name, type = col.strip.split(':')
        [name, (type || 'varchar(255)').downcase.to_sym]
      end
    end

    def init_db_by_csv(csv)
      header = parser_header(csv.readline)

      cols = header.map { |name, type| "#{name} #{type}" }.join(', ')
      sql = "CREATE TABLE csv (#{cols});"
      execute sql

      cache = []
      col_names = header.map(&:first)
      csv.each do |line|
        if cache.length > BATCH_LINES then
          import_lines(cache, col_names)
          cache.clear
        else
          cache << line.each_with_index.map { |v, i| format_sql_val(v, header[i][1]) }
        end
      end
      import_lines(cache, col_names) unless cache.empty?
      db
    end

    def import_lines(lines, col_names)
      sql = "INSERT INTO csv (#{col_names.join(', ')}) VALUES "
      values = lines.map { |line| "(#{line.join(',')})" }.join(', ')
      execute sql + values
    end

    def format_sql_val(val, type)
      case type
      when :int, :integer then val.to_i
      when :float, :double then val.to_f
      when :date then "'#{Date.parse(val).to_s}'"
      when :datetime then "'#{Time.parse(val).strftime('%F %T')}'"
      else
        "'#{val.gsub("'", "''")}'"
      end
    rescue => e
      process_sql_error("Parse val: #{val}", e)
    end

    def process_sql_error(sql, err)
      $stderr.puts(sql)

      if @error_action == :exit
        $stderr.puts(e.message)
        exit
      else
        raise err
      end
    end

    def get_db_path(csv_path)
      csv_path = csv_path || ''
      return '' unless File.exist?(csv_path)

      if use_cache
        stat = File.stat(csv_path)
        filename = Digest::SHA2.hexdigest(File.absolute_path(csv_path)) + '.cache'
        file_stat = [File.absolute_path(csv_path), stat.size, stat.ctime].join("\n")
        stat_path = File.join(CACHE_DIR, filename.gsub(/\.cache$/, '.stat'))
        cache_path = File.join(CACHE_DIR, filename)

        if File.exist?(stat_path)
          if File.read(stat_path) == file_stat
            cache_path
          else
            FileUtils.rm(cache_path)
            cache_path
          end
        else
          File.write(stat_path, file_stat)
          cache_path
        end
      else
        ''
      end
    end
  end
end
