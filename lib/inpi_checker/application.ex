defmodule InpiChecker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = System.get_env("PORT", "4000") |> String.to_integer()

    children = [
      {Task.Supervisor, name: InpiChecker.TaskSupervisor},
      InpiChecker.Session,
      {Bandit, plug: InpiChecker.Web.Router, port: port, thousand_island_options: [read_timeout: 300_000]}
    ]

    opts = [strategy: :one_for_one, name: InpiChecker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
