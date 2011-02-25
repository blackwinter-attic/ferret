module Ferret::Search
  # A Hit that knows about its associated fields. See Index#term_vector_fields.
  class HitWithFields < Hit

    attr_reader :fields

    def initialize(hit, fields)
      super(*hit)
      @fields = fields
    end

  end
end
