defmodule InpiChecker.Session do
  @moduledoc """
  GenServer that maintains an authenticated HTTP session with INPI.
  Handles cookie management and automatic re-authentication.
  """

  use GenServer
  require Logger

  @base_url "https://busca.inpi.gov.br/pePI"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Get a configured Req client with session cookies"
  def get_client do
    GenServer.call(__MODULE__, :get_client, 30_000)
  end

  @doc "Force session refresh (re-authenticate)"
  def refresh do
    GenServer.call(__MODULE__, :refresh, 30_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{cookies: %{}, authenticated: false}, {:continue, :init_session}}
  end

  @impl true
  def handle_continue(:init_session, state) do
    case init_session() do
      {:ok, cookies} ->
        Logger.info("INPI session initialized successfully")
        {:noreply, %{state | cookies: cookies, authenticated: true}}

      {:error, reason} ->
        Logger.warning("Failed to initialize INPI session: #{inspect(reason)}")
        {:noreply, %{state | cookies: %{}, authenticated: false}}
    end
  end

  @impl true
  def handle_call(:get_client, _from, %{cookies: cookies} = state) do
    client = build_client_with_cookies(cookies)
    {:reply, client, state}
  end

  @impl true
  def handle_call(:refresh, _from, _state) do
    case init_session() do
      {:ok, cookies} ->
        {:reply, :ok, %{cookies: cookies, authenticated: true}}

      {:error, reason} ->
        {:reply, {:error, reason}, %{cookies: %{}, authenticated: false}}
    end
  end

  # Private Functions

  defp init_session do
    username = Application.get_env(:inpi_checker, :inpi_user)
    password = Application.get_env(:inpi_checker, :inpi_password)

    # Step 1: Access the main page to get initial cookies
    client = build_base_client()

    with {:ok, cookies} <- access_main_page(client),
         {:ok, cookies} <- do_login(cookies, username, password) do
      {:ok, cookies}
    end
  end

  defp build_base_client do
    Req.new(
      base_url: @base_url,
      headers: [
        {"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
        {"accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
        {"accept-language", "pt-BR,pt;q=0.9,en;q=0.8"}
      ],
      receive_timeout: Application.get_env(:inpi_checker, :request_timeout, 60_000),
      redirect: true,
      retry: false
    )
  end

  defp build_client_with_cookies(cookies) do
    cookie_header = cookies |> Enum.map(fn {k, v} -> "#{k}=#{v}" end) |> Enum.join("; ")

    Req.new(
      base_url: @base_url,
      headers: [
        {"user-agent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"},
        {"accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"},
        {"accept-language", "pt-BR,pt;q=0.9,en;q=0.8"},
        {"cookie", cookie_header}
      ],
      receive_timeout: Application.get_env(:inpi_checker, :request_timeout, 60_000),
      redirect: true,
      retry: false
    )
  end

  defp access_main_page(client) do
    case Req.get(client, url: "/jsp/marcas/Pesquisa_num_processo.jsp") do
      {:ok, %{status: status, headers: headers}} when status in 200..399 ->
        cookies = extract_cookies(headers)
        {:ok, cookies}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_login(initial_cookies, username, password) do
    client = build_client_with_cookies(initial_cookies)

    # For anonymous access, we just need to hit the login controller
    # with action=login and empty credentials
    form_data =
      if username && password do
        [{"login", username}, {"senha", password}]
      else
        []
      end

    case Req.post(client, url: "/servlet/LoginController?action=login", form: form_data) do
      {:ok, %{status: status, headers: headers, body: body}} when status in 200..399 ->
        new_cookies = extract_cookies(headers)
        merged_cookies = Map.merge(initial_cookies, new_cookies)

        # Check if we got past the login page
        if String.contains?(body, "Pesquisa") and not String.contains?(body, "T_Login") do
          Logger.info("INPI session established (#{if username, do: "authenticated", else: "anonymous"})")
          {:ok, merged_cookies}
        else
          # Try to extract JSESSIONID from the body or try again
          Logger.warning("Login may have failed, but continuing with cookies")
          {:ok, merged_cookies}
        end

      {:ok, %{status: status}} ->
        {:error, {:login_failed, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_cookies(headers) do
    headers
    |> Enum.filter(fn {name, _} -> String.downcase(name) == "set-cookie" end)
    |> Enum.flat_map(fn {_, value} -> normalize_cookie_value(value) end)
    |> Enum.map(&parse_cookie/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  # Handle both single string and list of strings (multiple set-cookie headers)
  defp normalize_cookie_value(value) when is_list(value), do: value
  defp normalize_cookie_value(value) when is_binary(value), do: [value]

  defp parse_cookie(cookie_string) when is_binary(cookie_string) do
    case String.split(cookie_string, ";") |> List.first() |> String.split("=", parts: 2) do
      [name, value] -> {String.trim(name), String.trim(value)}
      _ -> nil
    end
  end

  defp parse_cookie(_), do: nil
end
