defmodule Mastery.Boundary.QuizSession do
  alias Mastery.Core.{
    Quiz,
    Response
  }

  use GenServer

  ### API

  def start_link(quiz, email) do
    GenServer.start_link(__MODULE__, {quiz, email})
  end

  def select_question(session) do
    GenServer.call(session, :select_question)
  end

  def answer_question(session, answer) do
    GenServer.call(session, {:answer_question, answer})
  end

  ### Callbacks

  @impl true
  def init({_quiz, _email} = initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_call(:select_question, _from, {quiz, email}) do
    new_quiz = Quiz.select_question(quiz)
    {:reply, new_quiz.current_question.asked, {new_quiz, email}}
  end

  def handle_call({:answer_question, answer}, _from, {quiz, email}) do
    quiz
    |> Quiz.answer_question(Response.new(quiz, email, answer))
    |> Quiz.select_question()
    |> maybe_finish(email)
  end

  ### Implementation

  defp maybe_finish(nil, _email), do: {:stop, :normal, :finished, nil}

  defp maybe_finish(quiz, email) do
    {
      :reply,
      {quiz.current_question.asked, quiz.last_response.correct},
      {quiz, email}
    }
  end
end
