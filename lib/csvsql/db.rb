# frozen_string_literal: true

class Csvsql::Db
  BATCH_ROWS = 10000

  attr_reader :data_source, :batch_rows

  def initialize(batch_rows: nil, sql_error_action: nil)
    @db = nil
    @data_source = {}
    @batch_rows = batch_rows || BATCH_ROWS
    @sql_error_action = (sql_error_action || :raise).to_sym
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

  def db
    @db ||= init_db
  end

  def init_db(cache_path = '')
    @db = SQLite3::Database.new(cache_path)
  end

  # Params:
  #   csv_data_or_path:
  #     [String] csv path
  #     [StringIO, IO] csv buffer io
  #     [Hash] { table_name => csv_path }
  def import(csv_data_or_path, encoding: 'utf-8')
    case csv_data_or_path
    when StringIO, IO
      data_source['csv'] = CSV.new(csv_data_or_path)
    when Hash
      csv_data_or_path.each do |table_name, path|
        data_source[table_name.to_s] = CSV.open(path, "r:#{encoding}")
      end
    else
      data_source['csv'] = CSV.open(csv_data_or_path, "r:#{encoding}")
    end

    tables = db.execute("SELECT name FROM sqlite_master WHERE type='table';").flatten
    data_source.each do |table_name, csv|
      next if tables.include?('csv')
      init_table_by_csv(table_name, csv)
    end
    true
  end

  private

  def parser_header(csv_header)
    csv_header.map do |col, r|
      name, type = col.strip.split(':')
      [name.gsub(/[\s-]+/, '_'), (type || 'varchar(255)').downcase.to_sym]
    end
  end

  def init_table_by_csv(table_name, csv)
    header = parser_header(csv.readline)

    cols = header.map { |name, type| "#{name} #{type}" }.join(', ')
    sql = "CREATE TABLE #{table_name} (#{cols});"
    execute sql

    cache = []
    col_names = header.map(&:first)
    Csvsql::Tracker.commit(:import_csv)
    csv.each do |line|
      cache << header.each_with_index.map { |h, i| format_sql_val(line[i], h[1]) }

      if cache.length >= batch_rows then
        import_lines(table_name, cache, col_names)
        cache.clear
      end
    end
    import_lines(table_name, cache, col_names) unless cache.empty?
    Csvsql::Tracker.commit(:import_csv)
    db
  end

  def import_lines(table_name, lines, col_names)
    sql = Csvsql::Tracker.commit(:generate_import_sql) do
      s = "INSERT INTO #{table_name} (#{col_names.join(', ')}) VALUES "
      s += lines.map { |line| "(#{line.join(',')})" }.join(', ')
    end
    Csvsql::Tracker.commit(:execute_import_sql) { execute sql }
  end

  def format_sql_val(val, type)
    return 'null' if val.nil? || val.to_s.strip.empty?

    case type
    when :int, :integer then val.to_i
    when :float, :double then val.to_f
    when :date then "'#{Date.parse(val).to_s}'"
    when :datetime then "'#{Time.parse(val).strftime('%F %T')}'"
    else
      "'#{val.to_s.gsub("'", "''")}'"
    end
  rescue => e
    process_sql_error("Parse #{type} val: #{val}", e)
  end

  def process_sql_error(sql, err)
    $stderr.puts(sql)

    if @sql_error_action == :exit
      $stderr.puts(err.message)
      exit
    else
      raise err
    end
  end
end
