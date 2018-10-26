# frozen_string_literal: true

require 'optparse'

class Csvsql::CommandRunner
  def self.run!(argv)
    options = self.new.parse!(argv)
    return unless options

    if options[:clear_cache]
      Csvsql.clear_cache!
      puts "Completed clear cache."
      return
    end

    if options[:debug]
      Csvsql::Tracker.tracker = Csvsql::Tracker.new(Logger.new($stdout))
    end

    Csvsql.execute(
      options[:sql], options[:csv_data],
      use_cache: options[:use_cache],
      batch_rows: options[:batch_rows],
      sql_error_action: 'exit',
      encoding: options[:encoding]
    )
  end

  def options
    @options ||= { csv_paths: [] }
  end

  def parse!(argv)
    parser.parse!(argv)
    options[:sql] = argv.last

    paths = options.delete(:csv_paths)
    options[:csv_data] = case paths.size
    when 0
      $stdin
    when 1
      paths.first
    else
      paths.each_with_object({}) do |path, r|
        p, n = path.split(':')
        if n.nil? || n.empty?
          puts "You should give #{p} a name, example: #{p}:a_name"
          return false
        end
        r[n] = p
      end
    end

    return options
  end

  private

  def parser
    OptionParser.new do |opts|
      opts.banner = "Csvsql #{Csvsql::VERSION}\nUsage: csvsql [options] SQL"
      opts.version = Csvsql::VERSION

      opts.on(
        '-i', '--input path[:name]', "CSV file path, optional. read from stdin if no give." +
          " Name is required if have multiple files. This name will be a table name." +
          " It will be a database name if cache is enabled"
      ) do |path|
        options[:csv_paths] << path
      end

      opts.on('-c', '--use-cache', "Cache data in ~/.csvsql_cache. it will still reload if file was changed") do
        options[:use_cache] = true
      end

      opts.on(
        '-b', '--batch-rows n',
        "How many rows to import per batch. Default value is #{Csvsql::Db::BATCH_ROWS}"
      ) do |n|
        options[:batch_rows] = n.to_i
      end

      opts.on('-e', '--encoding encoding', "Set the file encoding, default is UTF-8") do |encoding|
        options[:encoding] = encoding
      end

      opts.on('--clear-cache', "Clear all cache data") do
        options[:clear_cache] = true
      end

      opts.on('--debug', "Print debug information") do
        options[:debug] = true
      end
    end
  end
end
