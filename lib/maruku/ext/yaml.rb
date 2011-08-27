require 'YAML'

module MaRuKu
  # Utility functions for dealing with strings.
  module Strings
    # Parses yaml headers, returning a hash.
    # `hash[:data]` is the message; 
    # that is, anything past the headers.
    #
    # Keys are downcased and converted to symbols; 
    # spaces become underscores.  For example:
    #
    # ---
    # My key: true
    # ---
    #
    # becomes:
    #
    # {:my_deg => true}
    #
    # @param s [String] the entire contents
    # @return [Symbol => String] The header values
    def parse_yaml_headers(s)
      headers = {}
      if s =~ /^(---\s*\n.*?\n?)^(---\s*$\n?)/m
        
        begin
          hash = YAML.load($1)
        rescue => e
          puts "YAML Exception reading #{name}: #{e.message}"
          hash = {}
        end
      end
      hash.each_pair do |yamlkey,yamlval| 
        k, v = normalize_key_and_value(yamlkey, yamlval)
        headers[k.to_sym] = v
      end
        
      headers[:data] = $' # the postmatch string
      headers
    end
  end
end