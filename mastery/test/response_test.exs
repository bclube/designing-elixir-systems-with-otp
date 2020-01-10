defmodule ResponseTest do
  use ExUnit.Case, async: true
  use QuizBuilders

  defp quiz() do
    fields = template_fields(generators: %{left: [1], right: [2]})

    build_quiz()
    |> Quiz.add_template(fields)
    |> Quiz.select_question()
  end

  defp response(answer) do
    Response.new(quiz(), "mathy@example.com", answer)
  end

  setup_all do
    [
      start_time: DateTime.utc_now(),
      right: response("3"),
      wrong: response("2"),
      end_time: DateTime.utc_now()
    ]
  end

  describe "a right response and a wrong response" do
    test "right answers are correct", %{right: right} do
      assert right.correct
    end

    test "wrong answers are not correct", %{wrong: wrong} do
      refute wrong.correct
    end

    test "a date/time stamp is added at build time", %{
      right: %{timestamp: timestamp},
      start_time: start_time,
      end_time: end_time
    } do
      assert %DateTime{} = timestamp
      assert start_time <= timestamp
      assert timestamp <= end_time
    end
  end
end
