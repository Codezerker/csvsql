RSpec.describe Csvsql::Db do
  let(:csv_path) { File.expand_path('../../test.csv', __FILE__) }

  around :each, clear_cache: true do |example|
    Csvsql.clear_cache!
    example.run
    Csvsql.clear_cache!
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

    it 'should not reimport if table is existed', clear_cache: true do
      subject = described_class.new

      subject.import(csv_path)
      subject.execute("delete from csv where name = 'a'")
      expect(subject.execute("select count(*) from csv")).to eql([[2]])

      expect_any_instance_of(CSV).to_not receive(:readline)
      expect_any_instance_of(CSV).to_not receive(:read)
      subject.import(csv_path)
      expect(subject.execute("select count(*) from csv")).to eql([[2]])
    end

    it 'should reimport if not found table', clear_cache: true do
      subject = described_class.new

      subject.import(csv_path)
      subject.execute("delete from csv where name = 'a'")
      expect(subject.execute("select count(*) from csv")).to eql([[2]])

      subject.execute("drop table csv")
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

    it 'should convert invalid char to _ for column name' do
      subject.import(StringIO.new("a 1,b-2\n1,2"))
      expect(subject.execute('pragma table_info(csv)')).to eql([
        [0, "a_1", "varchar(255)", 0, nil, 0],
        [1, "b_2", "varchar(255)", 0, nil, 0],
      ])
      expect(subject.execute('select * from csv')).to eql([
        ["1", '2']
      ])
    end

    it 'should import all data if rows > batch_rows' do
      subject = described_class.new(batch_rows: 1)
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

    it 'should import data with multi tables' do
      subject.import(a: csv_path, b: csv_path)
      subject.execute("delete from a where name = 'a'")

      expect(subject.execute('select * from a')).to eql([
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
        ["c", 39, 3.1, "2018-01-19 20:10:00"]
      ])
      expect(subject.execute('select * from b')).to eql([
        ["a", 12, 1.2, "2018-09-01 11:22:00"],
        ["b", 21, 2.3, "2018-03-10 01:20:00"],
        ["c", 39, 3.1, "2018-01-19 20:10:00"]
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

  describe '#init_db' do
    it 'should use memory db for default' do
      expect(subject.db.filename).to eql('')
    end

    it 'should change the db file by init db' do
      cache_path = File.join(Csvsql::CACHE_DIR, 'a')
      subject.init_db(cache_path)
      expect(subject.db.filename).to eql(cache_path)

      subject.init_db(cache_path + 'asdf')
      expect(subject.db.filename).to eql(cache_path + 'asdf')
    end
  end
end
