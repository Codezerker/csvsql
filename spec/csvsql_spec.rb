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
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)
      Csvsql.execute(sql, path)
    end

    it "should return result as csv" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', 'int'], each: nil)
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path)).to eql("a:text,b:int\nda,db\n")
    end

    it "should not join nil type" do
      allow(Csvsql::Db).to receive(:new).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', nil], each: nil)
      expect(csvdb).to receive(:import).with(path, encoding: nil)
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path)).to eql("a:text,b\nda,db\n")
    end

    it "should catch encoding opts" do
      expect(Csvsql::Db).to receive(:new).with(use_cache: true).and_return(csvdb)
      pst = double('pst', columns: ['a', 'b'], types: ['text', nil], each: nil)
      expect(csvdb).to receive(:import).with(path, encoding: 'utf-8')
      expect(csvdb).to receive(:prepare).with(sql).and_return(pst)

      allow(pst).to receive(:each) { |&block| block.call(['da', 'db']) }
      expect(Csvsql.execute(sql, path, encoding: 'utf-8', use_cache: true)).to eql("a:text,b\nda,db\n")
    end
  end
end
