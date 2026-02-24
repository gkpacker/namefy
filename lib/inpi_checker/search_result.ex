defmodule InpiChecker.SearchResult do
  @moduledoc """
  Struct representing the result of an INPI trademark search.
  """

  @type recommendation :: :clear | :caution | :blocked | :error

  @type conflict :: %{
          name: String.t(),
          process: String.t(),
          status: String.t(),
          holder: String.t(),
          risk: String.t()
        }

  @type t :: %__MODULE__{
          brand: String.t(),
          class: pos_integer(),
          class_description: String.t(),
          mode: :exact | :radical,
          search_performed: String.t(),
          total_results: non_neg_integer(),
          blocking_conflicts: [conflict()],
          potential_conflicts: [conflict()],
          safe_matches: [conflict()],
          recommendation: recommendation(),
          summary: String.t(),
          searched_at: DateTime.t()
        }

  defstruct [
    :brand,
    :class,
    :class_description,
    :mode,
    :search_performed,
    :total_results,
    :blocking_conflicts,
    :potential_conflicts,
    :safe_matches,
    :recommendation,
    :summary,
    :searched_at
  ]

  @doc "Convert to JSON-compatible map (matching Python output format)"
  def to_json(%__MODULE__{} = result) do
    %{
      "brand" => result.brand,
      "class" => result.class,
      "class_description" => result.class_description,
      "mode" => to_string(result.mode),
      "search_performed" => result.search_performed,
      "total_results" => result.total_results,
      "blocking_conflicts" => result.blocking_conflicts,
      "potential_conflicts" => result.potential_conflicts,
      "safe_matches" => result.safe_matches,
      "recommendation" => result.recommendation |> to_string() |> String.upcase(),
      "summary" => result.summary
    }
  end

  @doc "Create an error result"
  def error(brand, class, reason) do
    %__MODULE__{
      brand: brand,
      class: class,
      class_description: InpiChecker.NiceClasses.description(class),
      mode: :exact,
      search_performed: "error",
      total_results: 0,
      blocking_conflicts: [],
      potential_conflicts: [],
      safe_matches: [],
      recommendation: :error,
      summary: "Search failed: #{inspect(reason)}",
      searched_at: DateTime.utc_now()
    }
  end
end
