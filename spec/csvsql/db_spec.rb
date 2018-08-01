RSpec.describe Csvsql::Db do
  let(:csv_path) { File.expand_path('../../test.csv', __FILE__) }

  around :each, clear_cache: true do |example|
    described_class.clear_cache!
    example.run
    described_class.clear_cache!
  end

  describe '.clear_cache!' do
    it 'should remove all cache fiels' do
      cache_path = File.join(Csvsql::Db::CACHE_DIR, 'asdf')
      FileUtils.touch(cache_path)
      expect {
        Csvsql::Db.clear_cache!
      }.to change { File.exist?(cache_path) }.to(false)
    end
  end

  describe '#import' do
    it 'should create correct table' do
      subject.import(csv_path)

      expect(subject.execute('pragma table_info(csv)')).to eql([
        [0, "name", "varchar(255)", 0, nil, 0],
        [1, "total", "int", 0, nil, 0],
        [2, "price", "double", 0, nil, 0],
        [3, "created_at", "datetime", 0, nil, 0]
      ])
    end

    it 'should parse & import data to csv table' do
      subject.import(csv_path)
      expect(subject.execute('select * from csv')).to eql([
        ["a", 12, 1.2, "2018-09-01 11:22:00"],
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
        ["c", 39, 3.1, "2018-01-19 20:10:00"]
      ])
    end

    it 'should correct use these data' do
      subject.import(csv_path)
      expect(subject.execute("select name, total from csv where created_at < '2018-03-11'")).to eql([
        ["b", 21], ["c", 39]
      ])
    end

    it 'should import again if cache is false' do
      subject.import(csv_path)
      subject.execute("delete from csv where name = 'a'")
      expect(subject.execute("select count(*) from csv")).to eql([[2]])
      subject.import(csv_path)
      expect(subject.execute("select count(*) from csv")).to eql([[3]])
    end

    it 'should not reimport if cache is true', clear_cache: true do
      subject = described_class.new(use_cache: true)

      subject.import(csv_path)
      subject.execute("delete from csv where name = 'a'")
      expect(subject.execute("select count(*) from csv")).to eql([[2]])

      expect(CSV).to_not receive(:open)
      subject.import(csv_path)
      expect(subject.execute("select count(*) from csv")).to eql([[2]])
    end

    it 'should reimport if csv is changed', clear_cache: true do
      subject = described_class.new(use_cache: true)

      subject.import(csv_path)
      subject.execute("delete from csv where name = 'a'")
      expect(subject.execute("select count(*) from csv")).to eql([[2]])

      File.write(csv_path, File.read(csv_path))
      subject.import(csv_path)
      expect(subject.execute("select count(*) from csv")).to eql([[3]])
    end

    it 'should import by stringio' do
      subject.import(StringIO.new(File.read(csv_path)))
      expect(subject.execute('pragma table_info(csv)')).to eql([
        [0, "name", "varchar(255)", 0, nil, 0],
        [1, "total", "int", 0, nil, 0],
        [2, "price", "double", 0, nil, 0],
        [3, "created_at", "datetime", 0, nil, 0]
      ])
      expect(subject.execute('select * from csv')).to eql([
        ["a", 12, 1.2, "2018-09-01 11:22:00"],
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
        ["c", 39, 3.1, "2018-01-19 20:10:00"]
      ])
    end

    it 'should import all data if rows > batch_rows' do
      subject = described_class.new(use_cache: false, batch_rows: 1)
      subject.import(StringIO.new(File.read(csv_path)))
      expect(subject.execute('pragma table_info(csv)')).to eql([
        [0, "name", "varchar(255)", 0, nil, 0],
        [1, "total", "int", 0, nil, 0],
        [2, "price", "double", 0, nil, 0],
        [3, "created_at", "datetime", 0, nil, 0]
      ])
      expect(subject.execute('select * from csv')).to eql([
        ["a", 12, 1.2, "2018-09-01 11:22:00"],
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
        ["c", 39, 3.1, "2018-01-19 20:10:00"]
      ])
    end

    it 'should import empty or invalid data type' do
      subject.import(File.expand_path('../../test2.csv', __FILE__))
      expect(subject.execute('select * from csv')).to eql([
        ["a", 12, 1.2, "2018-09-01 11:22:00"],
        ["n", nil, nil, nil],
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
      ])
    end

    it 'should import file with a encoding' do
      subject.import(File.expand_path('../../test3_gb18030.csv', __FILE__), encoding: 'GB18030')
      expect(subject.execute('select * from csv')).to eql([
        ["中文", 12]
      ])
    end
  end

  describe '#prepare' do
    it 'should return prepare data' do
      subject.import(csv_path)
      pst = subject.prepare('select name, total from csv')
      expect(pst.columns).to eql(%w{name total})
      expect(pst.types).to eql(%w{varchar(255) int})
      expect(pst.to_a).to eql([['a', 12], ['b', 21], ['c', 39]])
    end
  end
end
