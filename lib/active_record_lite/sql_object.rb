require_relative './associatable'
require_relative './db_connection' # use DBConnection.execute freely here.
require_relative './mass_object'
require_relative './searchable'
require 'debugger'

class SQLObject < MassObject
  extend Searchable
  extend Associatable
  # sets the table_name
  def self.set_table_name(table_name)
    @table_name = table_name
  end

  # gets the table_name
  def self.table_name
    @table_name
  end

  # querys database for all records for this type. (result is array of hashes)
  # converts resulting array of hashes to an array of objects by calling ::new
  # for each row in the result. (might want to call #to_sym on keys)
  def self.all
    hashes = DBConnection.execute(<<-SQL)
                                  SELECT
                                    *
                                  FROM
                                    #{self.table_name}
    SQL
    
    parse_all(hashes)
  end

  # querys database for record of this type with id passed.
  # returns either a single object or nil.
  def self.find(id)
    result = DBConnection.execute(<<-SQL)
                                  SELECT
                                    *
                                  FROM
                                    #{self.table_name}
                                  WHERE
                                    id = #{id}
                                  LIMIT
                                    1
    SQL
    
    result.empty? ? nil : parse_all(result).first
  end

  # executes query that creates record in db with objects attribute values.
  # use send and map to get instance values.
  # after, update the id attribute with the helper method from db_connection
  def create
    columns = attribute_values
    values = columns.map{ |col| self.send(col) }
    quesiton_marks = (['?'] * columns.size).join(',')
        
    DBConnection.execute(<<-SQL, *values)
                          INSERT INTO
                            #{self.class.table_name}
                            (#{columns.join(',')})
                          VALUES
                            (#{quesiton_marks}) 
    SQL
  end

  # executes query that updates the row in the db corresponding to this instance
  # of the class. use "#{attr_name} = ?" and join with ', ' for set string.
  def update
    columns = self.class.attributes
    values = columns.map{ |col| self.send(col) }  
    columns = columns.map{ |col| "\"#{col}\" = ?" }
    sql = <<-SQL 
          UPDATE
            #{self.class.table_name}
          SET
            #{columns.join(',')}
          WHERE id = ?
          SQL
    DBConnection.execute(sql, *values, self.id)
  end

  # call either create or update depending if id is nil.
  def save
    self.id.nil? ? create : update
  end

  # helper method to return values of the attributes.
  def attribute_values
    self.class.attributes.map{ |attr| self.send(attr) }
  end
end
