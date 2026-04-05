# frozen_string_literal: true

require "test_helper"

class BruteRackTest < Minitest::Test
  def test_version
    refute_nil BruteRack::VERSION
  end
end
