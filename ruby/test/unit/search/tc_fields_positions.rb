require File.dirname(__FILE__) + "/../../test_helper"

class FieldsPositionsTest < Test::Unit::TestCase
  include Ferret::Store
  include Ferret::Index

  def setup
    @dir = RAMDirectory.new

    @docs = [
      { :title => 'Cats on a Roof', :description => 'Cats and flats',   :arf => 'foo' },
      { :title => 'Catwoman',       :description => 'Spandex and cats', :arf => 'bar' }
    ]

    @highlights = [
      { :title => '<b>Cats</b> on a Roof', :description => '<b>Cats</b> and flats',          :arf => 'foo' },
      { :title => 'Catwoman',              :description => '<b>Spandex</b> and <b>cats</b>', :arf => 'bar' }
    ]

    @query, @query_untokenized, @options = 'cat? OR span*', 'Catwoman', { :with_fields => true }
  end

  def teardown
    @dir.close
  end

  # FieldInfos:
  #
  #   :store =>
  #     :no                      # +
  #     :yes                     # + (default)
  #     :compressed              # +
  #
  #   :index =>
  #     :no                      # - can't store the term vectors of an unindexed field
  #     :yes                     # + (default)
  #     :untokenized             # +
  #     :omit_norms              # +
  #     :untokenized_omit_norms  # +
  #
  #   :term_vector =>
  #     :no                      # - no term vector, no fields
  #     :yes                     # / no offsets/positions, but fields
  #     :with_positions          # / no offsets, but fields
  #     :with_offsets            # / no positions, but fields
  #     :with_positions_offsets  # + (default)
  def setup_index(options = {})
    @index = Index.new(:dir => @dir, :field_infos => FieldInfos.new(options))
    @docs.each { |doc| @index << doc }

    [options[:index].to_s =~ /\Auntokenized/,
     options[:term_vector] != :with_positions_offsets]
  end

  def check(count, index_options)
    untokenized, no_highlight = setup_index(index_options)

    @hits = 0

    yield [untokenized ? @query_untokenized : @query, @options],
          [untokenized, no_highlight]

    assert_equal count, @hits
  end

  def check_search(*check_args)
    check(*check_args) { |search_args, highlight_args|
      @index.search(*search_args).hits.each { |hit|
        @hits += 1

        if block_given?
          yield hit
        else
          check_highlight(*highlight_args + [hit.doc, hit.score, hit.fields])
        end
      }
    }
  end

  def check_search_each(*check_args)
    check(*check_args) { |search_args, highlight_args|
      @index.search_each(*search_args) { |*args|
        @hits += 1
        block_given? ? yield(*args) : check_highlight(*highlight_args + args)
      }
    }
  end

  def check_highlight(untokenized, no_highlight, doc_id, score, fields)
    doc, highlight = @docs[doc_id], @highlights[doc_id]

    field_count, term_count = 0, 0

    fields.each { |field, terms|
      field_count += 1

      content = doc[field].dup
      length  = content.length

      terms.each { |term|
        break unless term.respond_to?(:offset)

        term_count += 1
        offset = term.offset

        content.insert(content.length - length + offset.start, '<b>')
        content.insert(content.length - length + offset.end,   '</b>')
      }

      assert_equal no_highlight ? doc[field] : untokenized ?
                   "<b>#{doc[field]}</b>" : highlight[field], content
    }

    assert_equal no_highlight ? 0 : untokenized ? 1 : 2, term_count
    assert_operator 0, :<, field_count if no_highlight
  end

  def test_search_with_fields_default
    check_search(2,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_each_with_fields_default
    check_search_each(2,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_with_fields_store_no
    check_search(2,
      :store => :no, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_each_with_fields_store_no
    check_search_each(2,
      :store => :no, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_with_fields_store_compressed
    check_search(2,
      :store => :compressed, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_each_with_fields_store_compressed
    check_search_each(2,
      :store => :compressed, :term_vector => :with_positions_offsets, :index => :yes
    )
  end

  def test_search_with_fields_index_no
    assert_raises(ArgumentError) { setup_index(
      :store => :yes, :term_vector => :with_positions_offsets, :index => :no
    ) }
  end

  def test_search_each_with_fields_index_no
    assert_raises(ArgumentError) { setup_index(
      :store => :yes, :term_vector => :with_positions_offsets, :index => :no
    ) }
  end

  def test_search_with_fields_index_untokenized
    check_search(1,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized
    )
  end

  def test_search_each_with_fields_index_untokenized
    check_search_each(1,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized
    )
  end

  def test_search_with_fields_index_omit_norms
    check_search(2,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :omit_norms
    )
  end

  def test_search_each_with_fields_index_omit_norms
    check_search_each(2,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :omit_norms
    )
  end

  def test_search_with_fields_index_untokenized_omit_norms
    check_search(1,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized_omit_norms
    )
  end

  def test_search_each_with_fields_index_untokenized_omit_norms
    check_search_each(1,
      :store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized_omit_norms
    )
  end

  def test_search_with_fields_term_vector_no
    check_search(2,
      :store => :yes, :term_vector => :no, :index => :yes
    ) { |hit| assert_equal 0, hit.fields.size }
  end

  def test_search_each_with_fields_term_vector_no
    check_search_each(2,
      :store => :yes, :term_vector => :no, :index => :yes
    ) { |doc, score, fields| assert_equal 0, fields.size }
  end

  def test_search_with_fields_term_vector_yes
    check_search(2,
      :store => :yes, :term_vector => :yes, :index => :yes
    )
  end

  def test_search_each_with_fields_term_vector_yes
    check_search_each(2,
      :store => :yes, :term_vector => :yes, :index => :yes
    )
  end

  def test_search_with_fields_term_vector_with_positions
    check_search(2,
      :store => :yes, :term_vector => :with_positions, :index => :yes
    )
  end

  def test_search_each_with_fields_term_vector_with_positions
    check_search_each(2,
      :store => :yes, :term_vector => :with_positions, :index => :yes
    )
  end

  def test_search_with_fields_term_vector_with_offsets
    check_search(2,
      :store => :yes, :term_vector => :with_offsets, :index => :yes
    )
  end

  def test_search_each_with_fields_term_vector_with_offsets
    check_search_each(2,
      :store => :yes, :term_vector => :with_offsets, :index => :yes
    )
  end

end
