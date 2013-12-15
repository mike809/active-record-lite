require 'active_support/core_ext/object/try'
require_relative './mass_object'
require 'active_support/inflector'
require_relative './db_connection.rb'
require 'debugger'

class AssocParams < MassObject
  
  def initialize(params)
    self.class.my_attr_accessor :primary_key, :foreign_key
    
    @foreign_key = params[:foreign_key]
    @primary_key = params[:primary_key]
    @other_class = params[:class_name]
    @other_table = params[:class_name].to_s.underscore + "s"
  end
 
  def other_class
    @other_class.constantize
  end

  def other_table
    @other_table
  end
  
end

class BelongsToAssocParams < AssocParams

  def initialize(name, params2)
    params = {
      :class_name => "#{name}".classify,
      :foreign_key => "#{name}".foreign_key,
      :primary_key => "id"
    }
    params.merge!(params2)
    super(params)
  end

  def type
    :belongs_to
  end
end

class HasManyAssocParams < AssocParams
  
  def initialize(name, params2, self_class)
    params = {
      :class_name => "#{name}".classify,
      :foreign_key => "#{self_class}".foreign_key,
      :primary_key => "id"
    }
    params.merge!(params2)
    super(params)
  end

  def type
    :has_many
  end
end

module Associatable
  
  def self.query_builder(assoc, other_table)
    if assoc.type == :belongs_to
      join = <<-SQL #(cats belongs to a human)
      JOIN 
        #{other_table} 
        ON
        #{other_table}.#{assoc.foreign_key} = 
        #{assoc.other_table}.#{assoc.primary_key} 
      SQL
    else
      join = <<-SQL #(human has many houses)
      JOIN
        #{other_table}  
      ON 
        #{assoc.other_table}.#{assoc.foreign_key} = 
        #{other_table}.#{assoc.primary_key} 
      SQL
    end
    join
  end
  
  def assoc_params
    @assoc_params ||= {}
  end

  def belongs_to(name, params = { })
    aps = BelongsToAssocParams.new(name, params)
    assoc_params[name] = aps
    
    define_method(name) do
      where_clause = { aps.primary_key => self.send(aps.foreign_key) }
      aps.other_class.where(where_clause).first
    end       
  end

  def has_many(name, params = {})
    
    if params.include?(:through)
      return has_many_through(name, params[:through], params[:source]) 
    end
    
    aps = HasManyAssocParams.new(name, params, self.class)  
    assoc_params[name] = aps
    
    define_method(name) do
      where_clause = { aps.foreign_key => self.send(aps.primary_key) }
      aps.other_class.where(where_clause)
    end
  end

  def has_one_through(name, assoc1, assoc2)
    through = assoc_params[assoc1]    
  
    define_method(name) do
      source = through.other_class.assoc_params[assoc2]
      
      sql = <<-SQL
        SELECT
          #{source.other_table}.*
        FROM
          #{source.other_table}
        JOIN
          #{through.other_table}
          ON
          #{source.foreign_key} = #{source.other_table}.#{source.primary_key} 
        WHERE
          #{through.other_table}.id = ?
        SQL
        
      foreign_key = self.send(through.foreign_key)  
      source.other_class.parse_all(DBConnection.execute(sql,foreign_key)).first
    end
  end
  
  def has_many_through(name, assoc1, assoc2)
    through = assoc_params[assoc1]    
    
    define_method(name) do
      source = through.other_class.assoc_params[assoc2]
      
      first_join = Associatable.query_builder(source, through.other_table)
      second_join = ""
      unless [source,through].all?{ |assoc| assoc.type == :has_many }
        second_join = Associatable.query_builder(through, self.class.table_name)
      end
      
      sql = <<-SQL
      SELECT
        #{source.other_table}.*
      FROM
        #{source.other_table}
      #{first_join}
      #{second_join}
      WHERE
        #{self.class.table_name}.#{through.primary_key} = #{self.id}
      SQL
      
      source.other_class.parse_all(DBConnection.execute(sql))
    end
  end
end