defmodule InpiChecker.SearchCoordinator do
  @moduledoc """
  Orchestrates parallel trademark searches with automatic retry.

  Features:
  - Spawns supervised tasks for parallel search execution
  - Fault isolation: one timeout/error doesn't affect other searches
  - Automatic retry with exponential backoff
  - Ensures all classes are checked before returning results
  """

  require Logger

  alias InpiChecker.{Searcher, SearchResult}

  @max_retries Application.compile_env(:inpi_checker, :max_retries, 3)
  @initial_backoff Application.compile_env(:inpi_checker, :initial_backoff, 2_000)
  @task_timeout 200_000

  @doc """
  Search for a trademark across multiple classes in parallel.

  Each search is executed in an isolated supervised task with automatic retry.
  Returns a list of results (successes and failures).

  ## Options
  - `:max_retries` - Maximum retry attempts per search (default: 3)
  - `:mode` - Search mode, `:exact` or `:radical` (default: :exact)
  """
  def search_parallel(brand, classes, opts \\ []) when is_list(classes) do
    max_retries = Keyword.get(opts, :max_retries, @max_retries)
    mode = Keyword.get(opts, :mode, :exact)

    classes
    |> Enum.map(fn class ->
      Task.Supervisor.async_nolink(InpiChecker.TaskSupervisor, fn ->
        search_with_retry(brand, class, mode, max_retries)
      end)
    end)
    |> Enum.zip(classes)
    |> Enum.map(fn {task, class} ->
      collect_result(task, brand, class)
    end)
  end

  @doc """
  Search for multiple brand variations in a single class in parallel.
  Useful for radical searches with different suffixes.
  """
  def search_variations(brands, class, opts \\ []) when is_list(brands) do
    max_retries = Keyword.get(opts, :max_retries, @max_retries)
    mode = Keyword.get(opts, :mode, :radical)

    brands
    |> Enum.map(fn brand ->
      Task.Supervisor.async_nolink(InpiChecker.TaskSupervisor, fn ->
        search_with_retry(brand, class, mode, max_retries)
      end)
    end)
    |> Enum.zip(brands)
    |> Enum.map(fn {task, brand} ->
      collect_result(task, brand, class)
    end)
  end

  # Private Functions

  defp search_with_retry(brand, class, mode, retries_left, attempt \\ 1) do
    case Searcher.search(brand, class, mode) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} when retries_left > 0 ->
        backoff = calculate_backoff(attempt)
        Logger.warning("Search failed for '#{brand}' class #{class}: #{inspect(reason)}. Retrying in #{backoff}ms (attempt #{attempt}/#{@max_retries})")
        Process.sleep(backoff)
        search_with_retry(brand, class, mode, retries_left - 1, attempt + 1)

      {:error, reason} ->
        Logger.error("Search failed for '#{brand}' class #{class} after #{attempt} attempts: #{inspect(reason)}")
        {:error, %{class: class, brand: brand, reason: reason, attempts: attempt}}
    end
  end

  defp calculate_backoff(attempt) do
    # Exponential backoff: 2s, 4s, 8s, ...
    trunc(@initial_backoff * :math.pow(2, attempt - 1))
  end

  defp collect_result(task, brand, class) do
    case Task.yield(task, @task_timeout) || Task.shutdown(task) do
      {:ok, {:ok, result}} ->
        {:ok, result}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:exit, reason} ->
        Logger.error("Task crashed for '#{brand}' class #{class}: #{inspect(reason)}")
        {:error, SearchResult.error(brand, class, {:task_crashed, reason})}

      nil ->
        Logger.error("Task timed out for '#{brand}' class #{class}")
        {:error, SearchResult.error(brand, class, :final_timeout)}
    end
  end
end
