defmodule InpiChecker.Searcher do
  @moduledoc """
  Performs trademark searches against INPI database.
  Handles exact and radical search modes.
  """

  alias InpiChecker.{Session, Parser, Classifier, SearchResult}

  @doc "Search for a trademark in a specific Nice class"
  def search(brand, class, mode, opts \\ []) do
    results_per_page = Keyword.get(opts, :results_per_page, 60)

    with {:ok, client} <- get_client(),
         {:ok, client} <- navigate_to_search(client),
         {:ok, all_entries} <- fetch_all_pages(client, brand, class, mode, results_per_page) do
      process_all_results(all_entries, brand, class, mode)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private Functions

  defp get_client do
    try do
      {:ok, Session.get_client()}
    rescue
      _ -> {:error, :session_unavailable}
    end
  end

  defp navigate_to_search(client) do
    case Req.get(client, url: "/jsp/marcas/Pesquisa_classe_basica.jsp") do
      {:ok, %{status: status}} when status in 200..399 ->
        {:ok, client}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Maximum pages to fetch to prevent infinite loops
  @max_pages 50

  defp fetch_all_pages(client, brand, class, mode, results_per_page) do
    # Fetch first page
    case perform_search(client, brand, class, mode, results_per_page, 1) do
      {:ok, html} ->
        if Parser.no_results?(html) do
          {:ok, []}
        else
          first_page_entries = Parser.parse_results(html)
          {_current, total_pages} = Parser.extract_pagination(html)

          # Fetch remaining pages if any
          if total_pages > 1 do
            remaining_entries =
              fetch_remaining_pages(client, brand, class, mode, results_per_page, 2, total_pages)

            all_entries =
              (first_page_entries ++ remaining_entries)
              |> Enum.uniq_by(fn m -> {m.name, m.process} end)

            {:ok, all_entries}
          else
            {:ok, first_page_entries}
          end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_remaining_pages(client, _brand, _class, _mode, _results_per_page, start_page, total_pages) do
    end_page = min(total_pages, @max_pages)

    start_page..end_page
    |> Enum.reduce([], fn page, acc ->
      # INPI uses GET with Action=nextPageMarca for pagination
      case fetch_page(client, page) do
        {:ok, html} ->
          entries = Parser.parse_results(html)
          acc ++ entries

        {:error, reason} ->
          require Logger
          Logger.warning("Failed to fetch page #{page}: #{inspect(reason)}")
          acc
      end
    end)
  end

  # INPI pagination uses GET request with Action=nextPageMarca
  defp fetch_page(client, page) do
    url = "/servlet/MarcasServletController?Action=nextPageMarca&page=#{page}"

    case Req.get(client, url: url) do
      {:ok, %{status: status, body: body}} when status in 200..399 ->
        cond do
          Parser.database_unavailable?(body) ->
            {:error, :database_unavailable}

          true ->
            {:ok, body}
        end

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Initial search - POST request (page parameter not used, pagination via GET)
  defp perform_search(client, brand, class, mode, results_per_page, _page) do
    is_exact = mode == :exact
    # INPI requires zero-padded class numbers (e.g., "09" not "9")
    class_str = class |> to_string() |> String.pad_leading(2, "0")

    form_data = [
      {"Action", "searchMarca"},
      {"tipoPesquisa", "BY_MARCA_CLASSIF_BASICA"},
      {"marca", brand},
      {"classeInter", class_str},
      {"buscaExata", if(is_exact, do: "sim", else: "nao")},
      {"txt", if(is_exact, do: "Pesquisa Exata", else: "Pesquisa Radical")},
      {"registerPerPage", to_string(results_per_page)}
    ]

    case Req.post(client, url: "/servlet/MarcasServletController", form: form_data) do
      {:ok, %{status: status, body: body}} when status in 200..399 ->
        cond do
          Parser.database_unavailable?(body) ->
            {:error, :database_unavailable}

          true ->
            {:ok, body}
        end

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp process_all_results(entries, brand, class, mode) do
    if Enum.empty?(entries) do
      {:ok,
       %SearchResult{
         brand: brand,
         class: class,
         class_description: InpiChecker.NiceClasses.description(class),
         mode: mode,
         search_performed: "#{mode}:#{brand}",
         total_results: 0,
         blocking_conflicts: [],
         potential_conflicts: [],
         safe_matches: [],
         recommendation: :clear,
         summary: "No results found for '#{brand}' in class #{class}",
         searched_at: DateTime.utc_now()
       }}
    else
      result = Classifier.classify(entries, brand, class, mode)
      {:ok, result}
    end
  end
end
