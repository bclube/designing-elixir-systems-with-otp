defmodule Mastery.Boundary.Proctor do
  use GenServer
  require Logger

  alias Mastery.Boundary.{
    QuizManager,
    QuizSession
  }

  ### API

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, [], options)
  end

  def schedule_quiz(proctor \\ __MODULE__, quiz, temps, start_at, end_at) do
    quiz = %{
      fields: quiz,
      templates: temps,
      start_at: start_at,
      end_at: end_at
    }

    GenServer.call(proctor, {:schedule_quiz, quiz})
  end

  ### Callbacks

  @impl true
  def init(quizzes) do
    {:ok, quizzes}
  end

  @impl true
  def handle_call({:schedule_quiz, quiz}, _from, quizzes) do
    now = DateTime.utc_now()

    ordered_quizzes =
      [quiz | quizzes]
      |> start_quizzes(now)
      |> Enum.sort(fn a, b ->
        date_time_less_than_or_equal?(a.start_at, b.start_at)
      end)

    build_reply_with_timeout({:reply, :ok}, ordered_quizzes, now)
  end

  @impl true
  def handle_info(:timeout, quizzes) do
    now = DateTime.utc_now()
    remaining_quizzes = start_quizzes(quizzes, now)
    build_reply_with_timeout({:noreply}, remaining_quizzes, now)
  end

  def handle_info({:end_quiz, title}, quizzes) do
    QuizManager.remove_quiz(title)

    title
    |> QuizSession.active_sessions_for()
    |> QuizSession.end_sessions()

    Logger.info("Stopped quiz #{title}.")

    handle_info(:timeout, quizzes)
  end

  ### Implementation

  defp build_reply_with_timeout(reply, quizzes, now) do
    reply
    |> append_state(quizzes)
    |> maybe_append_timeout(quizzes, now)
  end

  defp append_state(tuple, quizzes), do: Tuple.append(tuple, quizzes)

  defp maybe_append_timeout(tuple, [], _now), do: tuple

  defp maybe_append_timeout(tuple, [quiz | _], now) do
    timeout =
      quiz
      |> Map.fetch!(:start_at)
      |> DateTime.diff(now, :millisecond)

    Tuple.append(tuple, timeout)
  end

  defp start_quizzes(quizzes, now) do
    {ready, not_ready} =
      quizzes
      |> Enum.split_while(&date_time_less_than_or_equal?(&1.start_at, now))

    Enum.each(ready, &start_quiz(&1, now))

    not_ready
  end

  def start_quiz(quiz, now) do
    Logger.info("Starting quiz #{quiz.fields.title}...")
    QuizManager.build_quiz(quiz.fields)
    Enum.each(quiz.templates, &QuizManager.add_template(quiz, &1))
    timeout = DateTime.diff(now, quiz.end_at, :millisecond)
    IO.inspect(timeout)
    Process.send_after(self(), {:end_quiz, quiz.fields.title}, timeout)
  end

  defp date_time_less_than_or_equal?(a, b) do
    DateTime.compare(a, b) in ~w[lt eq]a
  end
end
