defmodule InpiChecker.Parser do
  @moduledoc """
  HTML parser for INPI search results using Floki.
  Extracts trademark information from INPI's HTML tables.
  """

  @doc "Parse INPI search results HTML and extract trademark entries"
  def parse_results(html) when is_binary(html) do
    # INPI uses ISO-8859-1 (Latin1) encoding, convert to UTF-8
    html_utf8 = ensure_utf8(html)

    case Floki.parse_document(html_utf8) do
      {:ok, document} ->
        results = extract_from_tables(document) ++ extract_from_links(document)

        results
        |> Enum.uniq_by(fn m -> {m.name, m.process} end)
        |> Enum.reject(&invalid_entry?/1)

      {:error, _reason} ->
        []
    end
  end

  # Navigation elements and other noise to filter out
  @noise_patterns [
    "Pesquisa Básica",
    "Marca",
    "Titular",
    "Cód. Figura",
    "Próxima",
    "Anterior",
    "Página",
    "Resultado",
    "Voltar"
  ]

  defp invalid_entry?(%{name: name}) do
    is_nil(name) or
      name == "" or
      String.length(name) < 3 or
      Regex.match?(~r/^\d{6,}$/, name) or
      Enum.any?(@noise_patterns, &String.contains?(name, &1))
  end

  defp ensure_utf8(html) do
    if String.valid?(html) do
      html
    else
      case :unicode.characters_to_binary(html, :latin1, :utf8) do
        {:error, _, _} -> html
        {:incomplete, _, _} -> html
        result when is_binary(result) -> result
      end
    end
  end

  @doc "Check if the HTML indicates database unavailability"
  def database_unavailable?(html) do
    lower = String.downcase(html)
    String.contains?(lower, "inacessível") or String.contains?(html, "SQLException")
  end

  @doc "Check if HTML indicates no results"
  def no_results?(html) do
    lower = String.downcase(html)
    String.contains?(lower, "nenhum") and String.contains?(lower, "resultado")
  end

  @doc "Extract pagination info from HTML - returns {current_page, total_pages}"
  def extract_pagination(html) when is_binary(html) do
    html_utf8 = ensure_utf8(html)

    # INPI format: "Mostrando página <b>1</b> de <b>2</b>"
    # Handle encoding issues (p�gina, página, pagina) and HTML tags
    pagination_patterns = [
      # With <b> tags around numbers (most common INPI format)
      ~r/[Pp][áa�]gina\s*<b>(\d+)<\/b>\s*de\s*<b>(\d+)<\/b>/u,
      # Without tags
      ~r/[Pp][áa�]gina\s*:?\s*(\d+)\s*(?:de|\/)\s*(\d+)/u,
      # Alternative: "página X de Y" with any encoding
      ~r/gina\s*<b>(\d+)<\/b>\s*de\s*<b>(\d+)<\/b>/
    ]

    result =
      Enum.find_value(pagination_patterns, fn pattern ->
        case Regex.run(pattern, html_utf8) do
          [_, current, total] -> {String.to_integer(current), String.to_integer(total)}
          _ -> nil
        end
      end)

    case result do
      nil ->
        # Fallback: try to find total results and calculate pages
        case extract_total_results(html_utf8) do
          nil -> {1, 1}
          _total -> {1, 1}
        end

      pagination ->
        pagination
    end
  end

  @doc "Check if there's a next page available"
  def has_next_page?(html) when is_binary(html) do
    html_utf8 = ensure_utf8(html)
    {current, total} = extract_pagination(html_utf8)

    # Also check for "Próxima" link that's not disabled
    has_next_link =
      case Floki.parse_document(html_utf8) do
        {:ok, doc} ->
          doc
          |> Floki.find("a")
          |> Enum.any?(fn link ->
            text = Floki.text(link) |> String.trim()
            href = Floki.attribute(link, "href") |> List.first() || ""
            (String.contains?(text, "Próxima") or String.contains?(text, "próxima") or
             String.contains?(text, ">") or String.contains?(text, ">>")) and
            String.length(href) > 0 and not String.contains?(href, "#")
          end)

        _ ->
          false
      end

    current < total or has_next_link
  end

  @doc "Extract the next page number if available"
  def next_page_number(html) when is_binary(html) do
    {current, total} = extract_pagination(html)

    if current < total do
      current + 1
    else
      nil
    end
  end

  defp extract_total_results(html) do
    # Look for patterns like "Total: 123" or "123 resultados"
    case Regex.run(~r/[Tt]otal\s*:?\s*(\d+)/, html) do
      [_, total] -> String.to_integer(total)
      nil ->
        case Regex.run(~r/(\d+)\s*resultado/u, html) do
          [_, total] -> String.to_integer(total)
          nil -> nil
        end
    end
  end

  # Private Functions

  defp extract_from_tables(document) do
    document
    |> Floki.find("table tr")
    |> Enum.flat_map(&extract_row/1)
  end

  defp extract_row(row) do
    cells = Floki.find(row, "td")

    # INPI table has 8 columns: Número, Prioridade, (tipo), Marca, (status icon), Situação, Titular, Classe
    if length(cells) >= 6 do
      texts = Enum.map(cells, &Floki.text(&1) |> String.trim())

      # Try structured extraction first for known 8-column format
      case extract_structured_row(cells) do
        nil -> extract_mark_info(texts)
        result -> result
      end
    else
      []
    end
  end

  # Extract from INPI's specific 8-column table format
  defp extract_structured_row(cells) when length(cells) >= 8 do
    process = cells |> Enum.at(0) |> Floki.text() |> String.trim()
    name = cells |> Enum.at(3) |> Floki.text() |> String.trim()
    status_text = cells |> Enum.at(5) |> Floki.text() |> String.trim()
    holder = cells |> Enum.at(6) |> Floki.text() |> String.trim()

    # Validate process number format
    if Regex.match?(~r/^\d{9,}$/, process) and String.length(name) > 0 do
      status = normalize_status(status_text)

      [
        %{
          name: name,
          process: process,
          status: status,
          holder: holder
        }
      ]
    else
      nil
    end
  end

  defp extract_structured_row(_cells), do: nil

  defp normalize_status(text) do
    lower = String.downcase(text)

    cond do
      String.contains?(lower, "registro") -> "Registro"
      String.contains?(lower, "pedido") -> "Pedido"
      String.contains?(lower, "arquiv") -> "Arquivado"
      String.contains?(lower, "indefer") -> "Indeferido"
      String.contains?(lower, "publicado") -> "Publicado"
      true -> "Desconhecido"
    end
  end

  defp extract_mark_info(texts) do
    # Look for process number pattern (9+ digits)
    process = Enum.find(texts, fn t -> Regex.match?(~r/^\d{9,}$/, t) end)

    # Look for status - INPI uses phrases like "Registro de marca em vigor"
    {status_text, status} = find_status_in_texts(texts)

    # The name is typically the longest non-numeric, non-status text
    name =
      texts
      |> Enum.reject(fn t ->
        t == process or t == status_text or String.length(t) < 2 or Regex.match?(~r/^\d+$/, t)
      end)
      |> Enum.max_by(&String.length/1, fn -> nil end)

    # Holder is another text that's not name/process/status
    holder =
      texts
      |> Enum.reject(fn t ->
        t == process or t == status_text or t == name or String.length(t) < 2
      end)
      |> List.first()

    if name && status do
      [
        %{
          name: name,
          process: process || "",
          status: status,
          holder: holder || ""
        }
      ]
    else
      []
    end
  end

  # Status detection with partial matching for INPI's verbose status strings
  @status_patterns [
    {"Registro", "Registro"},
    {"registro de marca em vigor", "Registro"},
    {"Pedido", "Pedido"},
    {"pedido de registro", "Pedido"},
    {"Arquivado", "Arquivado"},
    {"arquivamento", "Arquivado"},
    {"Indeferido", "Indeferido"},
    {"indeferimento", "Indeferido"},
    {"Publicado", "Publicado"}
  ]

  defp find_status_in_texts(texts) do
    Enum.find_value(texts, {nil, nil}, fn text ->
      lower_text = String.downcase(text)

      Enum.find_value(@status_patterns, nil, fn {pattern, normalized_status} ->
        if String.contains?(lower_text, String.downcase(pattern)) do
          {text, normalized_status}
        end
      end)
    end)
  end

  defp extract_from_links(document) do
    document
    |> Floki.find("a")
    |> Enum.filter(fn link ->
      href = Floki.attribute(link, "href") |> List.first() || ""
      String.contains?(String.downcase(href), "processo") or
        String.contains?(String.downcase(href), "marca")
    end)
    |> Enum.flat_map(fn link ->
      name = Floki.text(link) |> String.trim()

      if String.length(name) > 1 do
        # Try to find status in parent row
        status = find_status_in_parent(link)

        [
          %{
            name: name,
            process: "",
            status: status,
            holder: ""
          }
        ]
      else
        []
      end
    end)
  end

  defp find_status_in_parent(element) do
    # This is a simplified version - in practice we'd need to traverse up
    # For now, default to unknown
    statuses = ["Registro", "Pedido", "Arquivado", "Indeferido"]
    text = Floki.text(element)

    Enum.find(statuses, "Desconhecido", fn s -> String.contains?(text, s) end)
  end
end
