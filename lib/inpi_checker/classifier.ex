defmodule InpiChecker.Classifier do
  @moduledoc """
  Classifies trademark search results by risk level.
  Uses string similarity to identify conflicts.
  """

  alias InpiChecker.{SearchResult, NiceClasses}

  @similarity_threshold 0.8

  @doc "Classify parsed trademark entries and build a SearchResult"
  def classify(entries, brand, class, mode) do
    {blocking, potential, safe} =
      Enum.reduce(entries, {[], [], []}, fn entry, {blocking, potential, safe} ->
        categorize_entry(entry, brand, {blocking, potential, safe})
      end)

    recommendation = determine_recommendation(blocking, potential)
    summary = build_summary(blocking, potential, safe, class, recommendation)

    %SearchResult{
      brand: brand,
      class: class,
      class_description: NiceClasses.description(class),
      mode: mode,
      search_performed: "#{mode}:#{brand}",
      total_results: length(entries),
      blocking_conflicts: Enum.reverse(blocking),
      potential_conflicts: Enum.reverse(potential),
      safe_matches: Enum.reverse(safe),
      recommendation: recommendation,
      summary: summary,
      searched_at: DateTime.utc_now()
    }
  end

  # Private Functions

  defp categorize_entry(entry, search_brand, {blocking, potential, safe}) do
    name = String.upcase(entry.name)
    search_upper = String.upcase(search_brand)
    status = entry.status

    is_exact = name == search_upper

    is_very_similar =
      String.contains?(name, search_upper) or
        String.contains?(search_upper, name) or
        similar?(name, search_upper)

    result_entry = %{
      name: entry.name,
      process: entry.process,
      status: status,
      holder: entry.holder,
      risk: "LOW"
    }

    case {status, is_exact or is_very_similar} do
      {"Registro", true} ->
        {[%{result_entry | risk: "HIGH"} | blocking], potential, safe}

      {"Registro", false} ->
        {blocking, [%{result_entry | risk: "MEDIUM"} | potential], safe}

      {"Pedido", true} ->
        {blocking, [%{result_entry | risk: "MEDIUM"} | potential], safe}

      {"Pedido", false} ->
        {blocking, potential, [result_entry | safe]}

      _ ->
        # Arquivado, Indeferido, etc.
        {blocking, potential, [result_entry | safe]}
    end
  end

  defp similar?(s1, s2) do
    # Ensure strings are valid UTF-8 before comparison
    s1_safe = safe_string(s1)
    s2_safe = safe_string(s2)

    if String.length(s1_safe) == 0 or String.length(s2_safe) == 0 do
      false
    else
      try do
        String.jaro_distance(s1_safe, s2_safe) >= @similarity_threshold
      rescue
        _ -> false
      end
    end
  end

  # Convert potentially Latin1/ISO-8859-1 encoded strings to UTF-8
  defp safe_string(str) when is_binary(str) do
    if String.valid?(str) do
      str
    else
      # Try to convert from Latin1 to UTF-8
      :unicode.characters_to_binary(str, :latin1, :utf8)
      |> case do
        {:error, _, _} -> ""
        {:incomplete, _, _} -> ""
        result when is_binary(result) -> result
      end
    end
  end

  defp safe_string(_), do: ""

  defp determine_recommendation(blocking, potential) do
    cond do
      length(blocking) > 0 -> :blocked
      length(potential) > 0 -> :caution
      true -> :clear
    end
  end

  defp build_summary(blocking, potential, safe, class, recommendation) do
    case recommendation do
      :blocked ->
        "Found #{length(blocking)} active registration(s) blocking this brand in class #{class}"

      :caution ->
        "Found #{length(potential)} pending/similar trademark(s) - recommend legal review"

      :clear ->
        total = length(blocking) + length(potential) + length(safe)

        if total == 0 do
          "No conflicts found in class #{class}"
        else
          "Found #{total} result(s), all archived or unrelated"
        end
    end
  end
end
