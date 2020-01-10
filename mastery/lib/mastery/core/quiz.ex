defmodule Mastery.Core.Quiz do
  alias Mastery.Core.{Template, Question, Response}
  @behaviour Access

  defstruct title: nil,
            mastery: 3,
            templates: %{},
            used: [],
            current_question: nil,
            last_response: nil,
            record: %{},
            mastered: []

  def new(fields) do
    struct!(__MODULE__, fields)
  end

  def add_template(%__MODULE__{} = quiz, fields) do
    template = Template.new(fields)

    update_in(
      quiz,
      [
        :templates,
        template.category
      ],
      &add_to_list_or_nil(&1, template)
    )
  end

  def select_question(%__MODULE__{templates: t}) when map_size(t) == 0, do: nil

  def select_question(quiz) do
    quiz
    |> pick_current_question()
    |> move_template(:used)
    |> reset_template_cycle()
  end

  def answer_question(quiz, %Response{correct: true} = response) do
    new_quiz =
      quiz
      |> inc_record()
      |> save_response(response)

    maybe_advance(new_quiz, mastered?(new_quiz))
  end

  def answer_question(quiz, %Response{correct: false} = response) do
    quiz
    |> reset_record()
    |> save_response(response)
  end

  def save_response(quiz, response) do
    Map.put(quiz, :last_response, response)
  end

  def mastered?(quiz) do
    score = Map.get(quiz.record, template(quiz).name, 0)
    score == quiz.mastery
  end

  def advance(quiz) do
    quiz
    |> move_template(:mastered)
    |> reset_record()
    |> reset_used()
  end

  defp add_to_list_or_nil(nil, template), do: [template]
  defp add_to_list_or_nil(templates, template), do: [template | templates]

  defp pick_current_question(quiz) do
    Map.put(
      quiz,
      :current_question,
      select_a_random_question(quiz)
    )
  end

  defp select_a_random_question(quiz) do
    quiz.templates
    |> Enum.random()
    |> elem(1)
    |> Enum.random()
    |> Question.new()
  end

  defp move_template(quiz, field) do
    quiz
    |> remove_template_from_category()
    |> add_template_to_field(field)
  end

  defp template(quiz), do: quiz.current_question.template

  defp remove_template_from_category(quiz) do
    template = template(quiz)

    new_category_templates =
      quiz.templates
      |> Map.fetch!(template.category)
      |> List.delete(template)

    new_templates =
      if new_category_templates == [] do
        Map.delete(quiz.templates, template.category)
      else
        Map.put(quiz.templates, template.category, new_category_templates)
      end

    Map.put(quiz, :templates, new_templates)
  end

  defp add_template_to_field(quiz, field) do
    template = template(quiz)
    list = Map.get(quiz, field)

    Map.put(quiz, field, [template | list])
  end

  defp reset_template_cycle(%__MODULE__{templates: templates, used: used} = quiz)
       when map_size(templates) == 0 do
    %__MODULE__{
      quiz
      | templates: Enum.group_by(used, fn template -> template.category end),
        used: []
    }
  end

  defp reset_template_cycle(quiz), do: quiz

  defp inc_record(%__MODULE__{current_question: question} = quiz) do
    update_in(
      quiz,
      [:record],
      &Map.update(&1, question.template.name, 1, fn v -> v + 1 end)
    )
  end

  defp maybe_advance(quiz, false = _mastered), do: quiz
  defp maybe_advance(quiz, true = _masterde), do: advance(quiz)

  defp reset_record(%{current_question: question} = quiz) do
    update_in(
      quiz,
      [:record],
      &Map.delete(&1, question.template.name)
    )
  end

  defp reset_used(%{current_question: question} = quiz) do
    update_in(
      quiz,
      [:used],
      &List.delete(&1, question.template)
    )
  end

  @impl true
  def get_and_update(%__MODULE__{} = quiz, key, fun), do: Map.get_and_update(quiz, key, fun)

  @impl true
  def fetch(%__MODULE__{} = quiz, key), do: Map.fetch(quiz, key)

  @impl true
  def pop(%__MODULE__{} = quiz, key), do: Map.pop(quiz, key)
end
