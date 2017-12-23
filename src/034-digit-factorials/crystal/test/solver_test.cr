require "minitest/autorun"
require "../src/solver"

class SolverTest < Minitest::Test
  def test_digit_sum
    assert_equal Solver.digit_sum([1, 1], [0, 0, 0, 0, 0, 0, 1]), 0
    assert_equal Solver.digit_sum([1, 1, 2], [0, 0, 0, 0, 0, 0, 2]), 0
    assert_equal Solver.digit_sum([1, 1, 2], [0, 0, 0, 0, 0, 1, 2]), 0
  end
end
