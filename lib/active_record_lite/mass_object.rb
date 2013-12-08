require 'debugger'

class MassObject
  # takes a list of attributes.
  # adds attributes to whitelist.
  def self.my_attr_accessible(*attributes)
    if @whitelist.nil? 
      @whitelist = attributes
    else
      @whitelist.concat(attributes)
    end
    @whitelist
  end

  # takes a list of attributes.
  # makes getters and setters
  def self.my_attr_accessor(*attributes)
    attributes.each do |ivar_name|
      define_method(ivar_name){ instance_variable_get("@#{ivar_name}") }
    
      define_method("#{ivar_name}=") do |value| 
        instance_variable_set("@#{ivar_name}", value)
      end
    end
  end

  # returns list of attributes that have been whitelisted.
  def self.attributes
    @whitelist
  end

  # takes an array of hashes.
  # returns array of objects.
  def self.parse_all(results)
    results.map do |params|
      self.new(params)
    end
  end

  # takes a hash of { attr_name => attr_val }.
  # checks the whitelist.
  # if the key (attr_name) is in the whitelist, the value (attr_val)
  # is assigned to the instance variable.
  def initialize(params = {})
    accesible_params = []
    params.each do |ivar_name, ivar_value|
      unless self.class.attributes.include?(ivar_name.to_sym)
        raise "mass assignment to unregistered attribute not_protected"
      end
      
      instance_variable_set("@#{ivar_name}", ivar_value)
    end
  end
  
end
