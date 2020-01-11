defmodule Mastery.Boundary.QuizManager do
  alias Mastery.Core.Quiz
  use Agent

  ### API

  def start_link(name \\ __MODULE__) do
    Agent.start_link(fn -> %{} end, name: name)
  end

  def build_quiz(name \\ __MODULE__, quiz_fields) do
    quiz = Quiz.new(quiz_fields)

    Agent.update(name, &Map.put(&1, quiz.title, quiz))
  end

  def add_template(name \\ __MODULE__, quiz_title, template_fields) do
    Agent.get_and_update(
      name,
      &Map.get_and_update(&1, quiz_title, fn
        nil -> :pop
        quiz -> {:ok, Quiz.add_template(quiz, template_fields)}
      end)
    ) || :error
  end

  def lookup_quiz_by_title(name \\ __MODULE__, quiz_title) do
    Agent.get(name, &Map.get(&1, quiz_title))
  end
end
