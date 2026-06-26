require "test_helper"

class IntakeAnswerTest < ActiveSupport::TestCase
  test "valid with answer" do
    letter = constituent_letters(:one)
    answer = IntakeAnswer.new(constituent_letter: letter, question: questions(:indigenous_impact), answer: "Test answer")
    assert answer.valid?
  end

  test "invalid without answer" do
    letter = constituent_letters(:one)
    answer = IntakeAnswer.new(constituent_letter: letter, question: questions(:indigenous_impact))
    assert_not answer.valid?
  end

  test "valid verdict is accepted" do
    letter = constituent_letters(:one)
    answer = IntakeAnswer.new(constituent_letter: letter, question: questions(:indigenous_impact), answer: "Test", verdict: "good")
    assert answer.valid?
  end

  test "invalid verdict is rejected" do
    letter = constituent_letters(:one)
    answer = IntakeAnswer.new(constituent_letter: letter, question: questions(:indigenous_impact), answer: "Test", verdict: "bad_verdict")
    assert_not answer.valid?
  end
end
