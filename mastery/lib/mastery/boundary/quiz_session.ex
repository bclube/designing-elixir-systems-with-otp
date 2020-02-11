defmodule Mastery.Boundary.QuizSession do
  alias Mastery.Core.{
    Quiz,
    Response
  }

  use GenServer

  def child_spec({%Quiz{} = quiz, email} = initial_state) do
    %{
      id: {__MODULE__, {quiz.title, email}},
      start: {__MODULE__, :start_link, [initial_state]},
      restart: :temporary
    }
  end

  def take_quiz(quiz, email) do
    DynamicSupervisor.start_child(
      Mastery.Supervisor.QuizSession,
      {__MODULE__, {quiz, email}}
    )
  end

  def via({_title, _email} = name) do
    {
      :via,
      Registry,
      {Mastery.Registry.QuizSession, name}
    }
  end

  ### API

  def start_link({%Quiz{} = quiz, email} = initial_state, _opts \\ []) do
    GenServer.start_link(__MODULE__, initial_state, name: via({quiz.title, email}))
  end

  def select_question(name) do
    GenServer.call(via(name), :select_question)
  end

  def answer_question(name, answer) do
    GenServer.call(via(name), {:answer_question, answer})
  end

  def remove_quiz(manager \\ __MODULE__, quiz_title) do
    GenServer.call(manager, {:remove_quiz, quiz_title})
  end

  def active_sessions_for(quiz_title) do
    Mastery.Supervisor.QuizSession
    |> DynamicSupervisor.which_children()
    |> Stream.filter(&child_pid?/1)
    |> Enum.flat_map(&active_sessions(&1, quiz_title))
  end

  def end_sessions(names) do
    Enum.each(names, fn name -> GenServer.stop(via(name)) end)
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

  def handle_call({:remove_quiz, quiz_title}, _from, quizzes) do
    new_quizzes = Map.delete(quizzes, quiz_title)
    {:reply, :ok, new_quizzes}
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

  defp child_pid?({:undefined, pid, :worker, [__MODULE__]}) when is_pid(pid), do: true
  defp child_pid?(_child), do: false

  defp active_sessions({:undefined, pid, :worker, [__MODULE__]}, title) do
    Mastery.Registry.QuizSession
    |> Registry.keys(pid)
    |> Enum.filter(fn {quiz_title, _email} ->
      quiz_title == title
    end)
  end
end
