module Csvsql
  class Db
    BATCH_LINES = 10000

    attr_reader :header

    def db
      @db ||= SQLite3::Database.new ''
    end

    def execute(sql)
      db.execute(sql)
    rescue SQLite3::SQLException => e
      $stderr.puts(sql)
      $stderr.puts(e.message)
      exit
    end

    def import(csv_path)
      csv = CSV.open(csv_path)
      @header = parser_header(csv.readline)

      init_db_by_header()

      cache = []
      csv.each do |line|
        if cache.length > BATCH_LINES then
          import_lines(cache)
          cache.clear
        else
          cache << line.each_with_index.map { |v, i| format_sql_val(v, header[i][1]) }
        end
      end
      import_lines(cache) unless cache.empty?
      db
    end

    private

    def parser_header(header)
      header.map do |col, r|
        name, type = col.strip.split(':')
        [name, (type || 'varchar(256)').downcase.to_sym]
      end
    end

    def init_db_by_header()
      cols = header.map { |name, type| "#{name} #{type}" }.join(', ')
      sql = "CREATE TABLE csv (#{cols});"
      execute sql
    end

    def import_lines(lines)
      sql = "INSERT INTO csv (#{header.map(&:first).join(', ')}) VALUES "
      values = lines.map { |line| "(#{line.join(',')})" }.join(', ')
      execute sql + values
    end

    def format_sql_val(val, type)
      case type
      when :int, :integer then val.to_i
      when :real, :float, :double then val.to_f
      # when :date, :datetime
      else
        "'#{val.gsub("'", "''")}'"
      end
    end
  end
end
