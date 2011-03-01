module Ferret::Search
  class Searcher

    # Determines +query+'s #query_terms_by_field (unless passed in +fields+)
    # and associates them with their offsets in the document identified by
    # +doc_id+ (see Ferret::Index::TermVector::TVTermWithOffset).
    #
    # If offsets and positions are not available for a field in this index
    # (the FieldInfo's <tt>:term_vector</tt> option is set to something other
    # than <tt>:with_positions_offsets</tt>, which is the default), just returns
    # the TermVector's terms associated with the document grouped by their field
    # name.
    #
    # This way you know exactly which terms (at which offsets) in a document
    # matched a particular query. It allows you to apply custom highlighting,
    # even when field contents are not stored (<tt>:store => :no</tt>).
    #
    # Example:
    #
    #   index = Index.new(:field_infos => FieldInfos.new(:store => :no))
    #
    #   docs  = [
    #     { :title => 'Cats on a Roof', :description => 'Cats and flats'   },
    #     { :title => 'Catwoman',       :description => 'Spandex and cats' }
    #   ].each { |doc| index << doc }
    #
    #   query = 'cat? OR span*'
    #
    #   index.search_each(query, :with_fields => true) { |id, score, fields|
    #     puts "doc #{id}: #{score}"
    #
    #     doc = docs[id]
    #
    #     fields.each { |field, terms|
    #       content = doc[field].dup
    #       length  = content.length
    #
    #       terms.each { |term|
    #         # in case we don't have offsets and positions for this field
    #         break unless term.respond_to?(:offset)
    #
    #         offset = term.offset
    #
    #         # highlight term
    #         content.insert(content.length - length + offset.start, '<b>')
    #         content.insert(content.length - length + offset.end,   '</b>')
    #       }
    #
    #       puts "#{field}: #{content}"
    #     }
    #   }
    def term_vector_fields(doc_id, query = nil, fields = nil)
      fields ||= query_terms_by_field(query) if query
      raise ArgumentError, 'wrong number of arguments (1 for 2)' unless query || fields

      fields_hash, tvto_class = {}, Ferret::Index::TermVector::TVTermWithOffset

      fields.each { |field, terms|
        next unless tv = reader.term_vector(doc_id, field)

        field_terms, have_offset = [], false

        terms.each { |term|
          tv.terms.each { |tvt|
            next unless tvt.text == term.text

            if tv.offsets && tvt.positions
              have_offset ||= true

              tvt.positions.each { |pos|
                field_terms << tvto_class.new(tvt, tv.offsets[pos])
              }
            else
              field_terms << tvt
            end

            break
          }
        }

        unless field_terms.empty?
          field_terms.sort! if have_offset
          fields_hash[field] = field_terms
        end
      }

      fields_hash
    end

    # Groups +query+'s query terms (see Query#terms) by their field name.
    def query_terms_by_field(query)
      group = Hash.new { |h, k| h[k] = [] }
      query.terms(self).each { |tvt| group[tvt.field] << tvt }
      group
    end

  end
end
