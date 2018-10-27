RSpec.describe Csvsql do
  it "has a version number" do
    expect(Csvsql::VERSION).not_to be nil
  end

  describe '.execute' do
    let(:csvdb) { Csvsql::Db.new }
    let(:path) { '/tmp/asdf.csv' }
    let(:sql) { 'select * from csv where 1 = 1' }

    it "should import data to csvdb and execute sql" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', 'int'], each: nil)
      expect(csvdb).to_not receive(:init_db)
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)
      Csvsql.execute(sql, path)
    end

    it "should return result as csv" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', 'int'], each: nil)
      expect(csvdb).to_not receive(:init_db)
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path)).to eql("a:text,b:int\nda,db\n")
    end

    it "should not join nil type" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', nil], each: nil)
      expect(csvdb).to_not receive(:init_db)
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path)).to eql("a:text,b\nda,db\n")
    end

    it "should catch encoding opts" do
      expect(Csvsql::Db).to receive(:new).with(batch_rows: 10).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', nil], each: nil)
      expect(csvdb).to_not receive(:init_db)
      expect(csvdb).to receive(:import).with(path, encoding: 'utf-8')
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path, encoding: 'utf-8', batch_rows: 10)).to eql("a:text,b\nda,db\n")
    end

    it "should import data to csvdb and execute sql with hash data" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', 'int'], each: nil)
      expect(csvdb).to_not receive(:init_db)
      expect(csvdb).to receive(:import).with({ a: path, b: path }, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)
      Csvsql.execute(sql, a: path, b: path)
    end

    context 'cache' do
      it 'should init db filename if cache is true and source is a path' do
        path = File.expand_path('../test.csv', __FILE__)
        expect(Csvsql::Db).to receive(:new).and_return(csvdb)
        pst = double('pst', columns: ['a', 'b'], types: ['text', nil], each: nil)
        expect(csvdb).to receive(:init_db).with(match(Csvsql::CACHE_DIR + '/'))
        expect(csvdb).to receive(:import).with(path, encoding: 'utf-8')
        expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

        allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
        expect(Csvsql.execute(sql, path, encoding: 'utf-8', use_cache: true)).to eql("a:text,b\nda,db\n")
      end

      it 'should init db filename if cache is true and source is a hash' do
        sql = "select * from a.csv where name = 'b' union select * from b.csv where name = 'c'"
        path = File.expand_path('../test.csv', __FILE__)
        expect_any_instance_of(Csvsql::Db).to receive(:init_db).with(match(Csvsql::CACHE_DIR + '/')) \
          .twice.and_call_original
        expect_any_instance_of(Csvsql::Db).to receive(:import).with(path, encoding: 'utf-8').twice.and_call_original
        expect_any_instance_of(Csvsql::Db).to receive(:prepare).with(sql).and_call_original

        # In Travis CI, that old version of SQLite3 cannot get column type
        col_names = if SQLite3.libversion <= 3008002
          "name,total,price,created_at\n"
        else
          "name:varchar(255),total:int,price:double,created_at:datetime\n"
        end
        expect(Csvsql.execute(sql, { a: path, b: path }, encoding: 'utf-8', use_cache: true)).to eql(
          col_names +
          "b,21,2.3,2018-03-10 01:20:00\n" +
          "c,39,3.1,2018-01-19 20:10:00\n"
        )
      end
    end
  end

  describe '.clear_cache!' do
    it 'should remove all cache fiels' do
      cache_path = File.join(Csvsql::CACHE_DIR, 'asdf')
      FileUtils.touch(cache_path)
      expect {
        Csvsql.clear_cache!
      }.to change { File.exist?(cache_path) }.to(false)
    end
  end
end
