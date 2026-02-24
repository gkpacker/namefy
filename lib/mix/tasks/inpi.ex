defmodule Mix.Tasks.Inpi do
  @moduledoc """
  Check trademark availability on Brazil's INPI database.

  ## Usage

      mix inpi "BrandName" 9 --mode exact
      mix inpi "BrandName" 9,36,42 --mode exact --parallel
      mix inpi "BrandName Finance" 36 --mode radical

  ## Options

      --mode      Search mode: "exact" or "radical" (default: exact)
      --parallel  Enable parallel search for multiple classes
      --debug     Enable debug output

  ## Examples

      # Exact search in class 9 (software)
      mix inpi "Horizon" 9

      # Parallel search in multiple classes
      mix inpi "Horizon" 9,36,42 --parallel

      # Radical search with a specific term
      mix inpi "Horizon Tech" 42 --mode radical
  """

  use Mix.Task

  @shortdoc "Check trademark availability on INPI"

  @switches [
    mode: :string,
    parallel: :boolean,
    debug: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, positional, _} = OptionParser.parse(args, switches: @switches)

    case positional do
      [brand, classes_str] ->
        Application.ensure_all_started(:inpi_checker)
        run_search(brand, classes_str, opts)

      _ ->
        Mix.shell().error("Usage: mix inpi \"BrandName\" <class> [--mode exact|radical] [--parallel]")
        Mix.shell().error("  Example: mix inpi \"Horizon\" 9,36,42 --parallel")
    end
  end

  defp run_search(brand, classes_str, opts) do
    mode = parse_mode(opts[:mode])
    classes = parse_classes(classes_str)
    parallel = opts[:parallel] || length(classes) > 1

    case {classes, parallel} do
      {[], _} ->
        Mix.shell().error("Invalid class number(s): #{classes_str}")

      {[class], false} ->
        run_single_search(brand, class, mode)

      {classes, true} ->
        run_parallel_search(brand, classes, mode)

      {[class], true} ->
        run_single_search(brand, class, mode)
    end
  end

  defp run_single_search(brand, class, mode) do
    Mix.shell().info("Searching for '#{brand}' in class #{class} (#{mode} mode)...")

    case InpiChecker.search(brand, class, mode) do
      {:ok, result} ->
        output_result(result)

      {:error, reason} ->
        output_error(brand, class, reason)
    end
  end

  defp run_parallel_search(brand, classes, mode) do
    classes_str = Enum.join(classes, ", ")
    Mix.shell().info("Searching for '#{brand}' in classes #{classes_str} (#{mode} mode, parallel)...")

    results = InpiChecker.search_parallel(brand, classes, mode: mode)
    output_results(results)
  end

  defp parse_mode("radical"), do: :radical
  defp parse_mode(_), do: :exact

  defp parse_classes(classes_str) do
    classes_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&parse_class/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_class(str) do
    case Integer.parse(str) do
      {num, ""} when num in 1..45 -> num
      _ -> nil
    end
  end

  defp output_result(result) do
    json = InpiChecker.to_json(result)
    IO.puts(json)
  end

  defp output_results(results) do
    json = InpiChecker.to_json(results)
    IO.puts(json)
  end

  defp output_error(brand, class, reason) do
    error_result = %{
      "brand" => brand,
      "class" => class,
      "error" => inspect(reason),
      "recommendation" => "ERROR"
    }

    IO.puts(Jason.encode!(error_result, pretty: true))
  end
end
