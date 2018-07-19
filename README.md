Csvsql
======

Use SQL to query your CSV file, and return a new CSV.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'csvsql'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install csvsql

## Usage

### Example CSV `mydata.csv`

```csv
name,total:int,created_at:datetime
a,12,2018-1-1 11:22
b,21,2018-3-1 10:20
c,39,2018-1-19 20:10
```

The first line is title for each columns. We use `:` split the title name and column type. the column type is `varchar(255)` if you did give a type.

There are same types: `int`, `integer` `float`, `double`, `date`, `datetime`, `varchar(255)`.

All sqlite3 type is supported, but maybe some type cannot convert to a sqlite3 value type.

### Query from file & Output

```
# csvsql [options] SQL
csvsql -h # Get help
```

```
$ csvsql -i mydata.csv "select * from csv where created_at > '2018-1-1' and total > 20" > /tmp/result.csv
# name:varchar(255),total:int,created_at:datetime
# b,21,2018-3-1 10:20:00
# c,39,2018-1-19 20:10:00

csvsql -i mydata.csv "select count(*) as total_record from csv where created_at > '2018-1-1'" > /tmp/result.csv
# total_record:integer
# 2

csvsql -i mydata.csv "select name, total from csv where total < 30" > /tmp/result.csv
# name:varchar(255),total:integer
# a,12
# b,21
```

### Query from stdin

If not give a csv by `-i`, we will get the input from stdin.

```
csvsql -i mydata.csv "select name, total from csv where total < 30" | csvsql "select count(*) as count from csv"
# count:integer
# 2
```

### Cache CSV data

It will save the CSV data to a tempfile. we use `~/.csvsql_cache` folder to save the cache

```
csvsql -i large.csv -c "select count(*) from csv"

# the second, it will be fast.
csvsql -i large.csv -c "select count(*) from csv"
```

### Clear Cache

This command will remove all data in the `~/.csvsql_cache`

```
csvsql --clear-cache
```


## Performance TODO

* 10,000 lines
* 10,000 lines with cache
* 1,000,000 lines
* 1,000,000 lines with cache


## Development

* Make sure your code has some testing.
* Run `rubocop -a` before commit your code.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/csvsql.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
