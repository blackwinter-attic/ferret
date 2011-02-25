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

    @query, @query_untokenized = 'cat? OR span*', 'Catwoman'
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
  end

  def teardown
    @dir.close
  end

  def check_highlight(doc_id, score, fields, untokenized = false, no_highlight = false)
    doc, highlight, field_count, term_count = @docs[doc_id], @highlights[doc_id], 0, 0

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
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_default
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_store_no
    setup_index(:store => :no, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_store_no
    setup_index(:store => :no, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_store_compressed
    setup_index(:store => :compressed, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_store_compressed
    setup_index(:store => :compressed, :term_vector => :with_positions_offsets, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_index_no
    assert_raises(ArgumentError) {
      setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :no)
    }
  end

  def test_search_each_with_fields_index_no
    assert_raises(ArgumentError) {
      setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :no)
    }
  end

  def test_search_with_fields_index_untokenized
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized)
    hits = 0
    @index.search_with_fields(@query_untokenized).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields, true)
    }
    assert_equal 1, hits
  end

  def test_search_each_with_fields_index_untokenized
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized)
    hits = 0
    @index.search_each_with_fields(@query_untokenized) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields, true)
    }
    assert_equal 1, hits
  end

  def test_search_with_fields_index_omit_norms
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :omit_norms)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_index_omit_norms
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :omit_norms)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_index_untokenized_omit_norms
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized_omit_norms)
    hits = 0
    @index.search_with_fields(@query_untokenized).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields, true)
    }
    assert_equal 1, hits
  end

  def test_search_each_with_fields_index_untokenized_omit_norms
    setup_index(:store => :yes, :term_vector => :with_positions_offsets, :index => :untokenized_omit_norms)
    hits = 0
    @index.search_each_with_fields(@query_untokenized) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields, true)
    }
    assert_equal 1, hits
  end

  def test_search_with_fields_term_vector_no
    setup_index(:store => :yes, :term_vector => :no, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      assert_equal 0, hit.fields.size
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_term_vector_no
    setup_index(:store => :yes, :term_vector => :no, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      assert_equal 0, fields.size
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_term_vector_yes
    setup_index(:store => :yes, :term_vector => :yes, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields, false, true)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_term_vector_yes
    setup_index(:store => :yes, :term_vector => :yes, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields, false, true)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_term_vector_with_positions
    setup_index(:store => :yes, :term_vector => :with_positions, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields, false, true)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_term_vector_with_positions
    setup_index(:store => :yes, :term_vector => :with_positions, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields, false, true)
    }
    assert_equal 2, hits
  end

  def test_search_with_fields_term_vector_with_offsets
    setup_index(:store => :yes, :term_vector => :with_offsets, :index => :yes)
    hits = 0
    @index.search_with_fields(@query).hits.each { |hit|
      hits += 1
      check_highlight(hit.doc, hit.score, hit.fields, false, true)
    }
    assert_equal 2, hits
  end

  def test_search_each_with_fields_term_vector_with_offsets
    setup_index(:store => :yes, :term_vector => :with_offsets, :index => :yes)
    hits = 0
    @index.search_each_with_fields(@query) { |doc, score, fields|
      hits += 1
      check_highlight(doc, score, fields, false, true)
    }
    assert_equal 2, hits
  end

end
