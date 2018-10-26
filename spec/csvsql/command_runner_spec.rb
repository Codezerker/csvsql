RSpec.describe Csvsql::CommandRunner do
  describe '#parse!' do
    it 'should parse argv' do
      cmd = %w{-i /path/a.csv --batch-rows 1000 -e gb18030} + ["select * from csv"]
      subject.parse!(cmd)
      expect(subject.options).to eql(
        sql: 'select * from csv',
        csv_data: '/path/a.csv',
        batch_rows: 1000,
        encoding: 'gb18030'
      )
    end

    it 'should parse multiple source' do
      cmd = %w{-i /path/a.csv:a -i /path/cc.csv:b --debug} + ["select * from csv where a = 1"]
      subject.parse!(cmd)
      expect(subject.options).to eql(
        sql: 'select * from csv where a = 1',
        csv_data: { 'a' => '/path/a.csv', 'b' => '/path/cc.csv' },
        debug: true
      )
    end

    it 'should parse clear-cache arg' do
      cmd = %w{--clear-cache}
      subject.parse!(cmd)
      expect(subject.options).to eql(clear_cache: true, csv_data: $stdin, sql: nil)
    end
  end

  describe '.run!' do
    let(:sql) { 'select * from csv' }
    let(:default_opts) { { use_cache: nil, batch_rows: nil, sql_error_action: 'exit', encoding: nil } }

    it 'should run by parsed options' do
      allow_any_instance_of(Csvsql::CommandRunner).to receive(:parse!).with('xxx').and_return(
        csv_data: $stdin, sql: sql
      )
      expect(Csvsql::Tracker).to_not receive(:tracker=)
      expect(Csvsql).to receive(:execute).with(sql, $stdin, default_opts)
      Csvsql::CommandRunner.run!('xxx')
    end

    it 'should set a new tracker if debug is true' do
      allow_any_instance_of(Csvsql::CommandRunner).to receive(:parse!).with('xxx').and_return(
        csv_data: $stdin, sql: sql, debug: true
      )
      expect(Csvsql::Tracker).to receive(:tracker=) do |v|
        expect(v.logger).to be_a(Logger)
      end
      expect(Csvsql).to receive(:execute).with(sql, $stdin, default_opts)
      Csvsql::CommandRunner.run!('xxx')
    end

    it 'should clear cache if clear_cache is true' do
      allow_any_instance_of(Csvsql::CommandRunner).to receive(:parse!).with('xxx').and_return(
        csv_data: $stdin, sql: sql, clear_cache: true
      )
      expect(Csvsql::Tracker).to_not receive(:tracker=)
      expect(Csvsql).to_not receive(:execute)
      Csvsql::CommandRunner.run!('xxx')
    end
  end
end
