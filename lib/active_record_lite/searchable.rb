require_relative './db_connection'
require 'debugger'

module Searchable
  # takes a hash like { :attr_name => :search_val1, :attr_name2 => :search_val2 }
  # map the keys of params to an array of  "#{key} = ?" to go in WHERE clause.
  # Hash#values will be helpful here.
  # returns an array of objects
  def where(params)
    where_clause = params.map do |key, value|
      "#{key} = ?"
    end
    
    sql = <<-SQL
    SELECT 
      *
    FROM
      #{self.table_name}
    WHERE
      #{where_clause.join(' AND ')}
    SQL
    
    parse_all(DBConnection.execute(sql, *params.values))
  end
end