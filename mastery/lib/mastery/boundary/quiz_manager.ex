defmodule Mastery.Boundary.QuizManager do
  alias Mastery.Core.Quiz
  use GenServer

  ### API

  def start_link(name \\ __MODULE__) do
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def build_quiz(name \\ __MODULE__, quiz_fields) do
    quiz = Quiz.new(quiz_fields)

    GenServer.call(name, {:add_quiz, quiz})
  end

  def add_template(name \\ __MODULE__, quiz_title, template_fields) do
    GenServer.call(name, {:add_template, quiz_title, template_fields})
  end

  def lookup_quiz_by_title(name \\ __MODULE__, quiz_title) do
    GenServer.call(name, {:lookup_quiz_by_title, quiz_title})
  end

  ### Callbacks

  @impl true
  def init(quizzes) when is_map(quizzes) do
    {:ok, quizzes}
  end

  @impl true
  def handle_call({:add_quiz, quiz}, _from, quizzes) do
    new_quizzes = Map.put(quizzes, quiz.title, quiz)

    {:reply, :ok, new_quizzes}
  end

  def handle_call({:add_template, quiz_title, template_fields}, _from, quizzes) do
    new_quizzes = Map.update!(quizzes, quiz_title, &Quiz.add_template(&1, template_fields))

    {:reply, :ok, new_quizzes}
  end

  def handle_call({:lookup_quiz_by_title, quiz_title}, _from, quizzes) do
    {:reply, quizzes[quiz_title], quizzes}
  end
end
