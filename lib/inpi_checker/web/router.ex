defmodule InpiChecker.Web.Router do
  use Plug.Router

  plug Plug.Logger
  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason

  plug :dispatch

  get "/" do
    file = Path.join(:code.priv_dir(:inpi_checker), "static/index.html")

    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, file)
  end

  get "/api/classes" do
    classes =
      InpiChecker.NiceClasses.all()
      |> Enum.map(fn {number, description} ->
        %{"number" => number, "description" => description}
      end)
      |> Enum.sort_by(& &1["number"])

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(classes))
  end

  post "/api/search" do
    with {:ok, brand} <- validate_brand(conn.body_params["brand"]),
         {:ok, classes} <- validate_classes(conn.body_params["classes"]),
         {:ok, mode} <- validate_mode(conn.body_params["mode"]) do
      results = InpiChecker.search_parallel(brand, classes, mode: mode)

      json =
        case results do
          {:error, reason} -> Jason.encode!(%{"error" => inspect(reason)})
          results when is_list(results) -> InpiChecker.to_json(results)
        end

      conn
      |> put_resp_content_type("application/json")
      |> send_resp(200, json)
    else
      {:error, message} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(422, Jason.encode!(%{"error" => message}))
    end
  end

  match _ do
    send_resp(conn, 404, "Not found")
  end

  defp validate_brand(nil), do: {:error, "brand is required"}
  defp validate_brand(""), do: {:error, "brand is required"}
  defp validate_brand(brand) when is_binary(brand), do: {:ok, String.trim(brand)}
  defp validate_brand(_), do: {:error, "brand must be a string"}

  defp validate_classes(nil), do: {:error, "classes is required"}
  defp validate_classes([]), do: {:error, "at least one class is required"}

  defp validate_classes(classes) when is_list(classes) do
    classes = Enum.map(classes, &to_integer/1)

    if Enum.all?(classes, &(&1 in 1..45)) do
      {:ok, classes}
    else
      {:error, "classes must be between 1 and 45"}
    end
  end

  defp validate_classes(_), do: {:error, "classes must be an array"}

  defp validate_mode(nil), do: {:ok, :exact}
  defp validate_mode("exact"), do: {:ok, :exact}
  defp validate_mode("radical"), do: {:ok, :radical}
  defp validate_mode(_), do: {:error, "mode must be 'exact' or 'radical'"}

  defp to_integer(n) when is_integer(n), do: n
  defp to_integer(n) when is_binary(n), do: String.to_integer(n)
end
