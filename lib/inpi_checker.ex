defmodule InpiChecker do
  @moduledoc """
  INPI Brand Availability Checker.

  Searches Brazil's INPI trademark database to check brand name availability.
  Designed for AI-driven parallel searches with JSON output.

  ## Usage

      # Single search
      InpiChecker.search("Horizon", 9, :exact)

      # Parallel search across multiple classes
      InpiChecker.search_parallel("Horizon", [9, 36, 42], mode: :exact)

      # Search variations (radical mode)
      InpiChecker.search_variations(["Horizon Tech", "Horizon App"], 42)
  """

  alias InpiChecker.{Searcher, SearchCoordinator, SearchResult, NiceClasses}

  @doc """
  Search for a trademark in a specific Nice class.

  Returns `{:ok, %SearchResult{}}` or `{:error, reason}`.

  Automatically fetches all pages of results (60 results per page by default).

  ## Options
  - `:results_per_page` - Number of results per page (default: 60)

  ## Examples

      InpiChecker.search("Horizon", 9, :exact)
      # => {:ok, %SearchResult{brand: "Horizon", class: 9, ...}}
  """
  def search(brand, class, mode \\ :exact, opts \\ []) do
    if NiceClasses.valid?(class) do
      Searcher.search(brand, class, mode, opts)
    else
      {:error, {:invalid_class, class}}
    end
  end

  @doc """
  Search for a trademark across multiple Nice classes in parallel.

  Each search runs in an isolated supervised task with automatic retry.
  Returns a list of `{:ok, result}` or `{:error, reason}` tuples.

  Automatically fetches all pages of results for each class.

  ## Options
  - `:mode` - Search mode, `:exact` or `:radical` (default: :exact)
  - `:max_retries` - Maximum retry attempts per search (default: 3)

  ## Examples

      InpiChecker.search_parallel("Horizon", [9, 36, 42])
      # => [{:ok, %SearchResult{}}, {:ok, %SearchResult{}}, {:ok, %SearchResult{}}]
  """
  def search_parallel(brand, classes, opts \\ []) when is_list(classes) do
    invalid_classes = Enum.reject(classes, &NiceClasses.valid?/1)

    if Enum.empty?(invalid_classes) do
      SearchCoordinator.search_parallel(brand, classes, opts)
    else
      {:error, {:invalid_classes, invalid_classes}}
    end
  end

  @doc """
  Search for multiple brand variations in a single class in parallel.

  Useful for checking variations like "Brand Tech", "Brand App", etc.

  Automatically fetches all pages of results for each variation.

  ## Options
  - `:mode` - Search mode (default: :radical)
  - `:max_retries` - Maximum retry attempts per search (default: 3)

  ## Examples

      InpiChecker.search_variations(["Horizon Tech", "Horizon Finance"], 36)
      # => [{:ok, %SearchResult{}}, {:ok, %SearchResult{}}]
  """
  def search_variations(brands, class, opts \\ []) when is_list(brands) do
    if NiceClasses.valid?(class) do
      SearchCoordinator.search_variations(brands, class, opts)
    else
      {:error, {:invalid_class, class}}
    end
  end

  @doc """
  Convert search results to JSON string.

  ## Examples

      {:ok, result} = InpiChecker.search("Horizon", 9, :exact)
      InpiChecker.to_json(result)
      # => JSON string with search results
  """
  def to_json(%SearchResult{} = result) do
    result
    |> SearchResult.to_json()
    |> Jason.encode!(pretty: true)
  end

  def to_json(results) when is_list(results) do
    results
    |> Enum.map(fn
      {:ok, result} -> SearchResult.to_json(result)
      {:error, %SearchResult{} = result} -> SearchResult.to_json(result)
      {:error, reason} -> %{"error" => inspect(reason), "recommendation" => "ERROR"}
    end)
    |> Jason.encode!(pretty: true)
  end
end
