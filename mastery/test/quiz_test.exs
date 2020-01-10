defmodule QuizTest do
  use ExUnit.Case, async: true
  use QuizBuilders

  describe "when a quiz has two templates" do
    setup [:quiz]

    test "the next question is ramdomly selected", %{quiz: quiz} do
      %{current_question: %{template: first_template}} = Quiz.select_question(quiz)

      other_template = eventually_pick_other_template(quiz, first_template)
      assert first_template != other_template
    end

    test "templates are unique until cycle repeats", %{quiz: quiz} do
      first_quiz = Quiz.select_question(quiz)
      second_quiz = Quiz.select_question(first_quiz)
      reset_quiz = Quiz.select_question(second_quiz)

      assert template(first_quiz) != template(second_quiz)
      assert template(reset_quiz) in [template(first_quiz), template(second_quiz)]
    end
  end

  describe "a quiz that always adds one and two" do
    setup [:quiz_always_adds_one_and_two]

    test "a wrong answer resets mastery", %{quiz: quiz} do
      quiz
      |> Quiz.select_question()
      |> assert_more_questions()
      |> answer_correctly()
      |> Quiz.select_question()
      |> assert_more_questions()
      |> answer_incorrectly()
      |> Quiz.select_question()
      |> assert_more_questions()
      |> answer_correctly()
      |> Quiz.select_question()
      |> assert_more_questions()
      |> answer_correctly()
      |> Quiz.select_question()
      |> refute_more_questions()
    end
  end

  defp eventually_pick_other_template(quiz, template) do
    Stream.repeatedly(fn -> Quiz.select_question(quiz).current_question.template end)
    |> Stream.take(1_000)
    |> Enum.find(&(&1 != template))
  end

  defp template(quiz) do
    quiz.current_question.template
  end

  defp answer_correctly(quiz), do: answer_question(quiz, "3")
  defp answer_incorrectly(quiz), do: answer_question(quiz, "wrong")

  defp answer_question(quiz, answer) do
    email = "xyz@email.com"
    response = Response.new(quiz, email, answer)
    Quiz.answer_question(quiz, response)
  end

  defp quiz(_context) do
    [quiz: build_quiz_with_two_templates()]
  end

  defp quiz_always_adds_one_and_two(_context) do
    fields = template_fields(generators: addition_generators([1], [2]))

    quiz =
      build_quiz(mastery: 2)
      |> Quiz.add_template(fields)

    [quiz: quiz]
  end

  defp assert_more_questions(quiz) do
    refute is_nil(quiz)
    quiz
  end

  defp refute_more_questions(quiz) do
    assert is_nil(quiz)
    quiz
  end
end
