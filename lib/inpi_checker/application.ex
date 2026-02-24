defmodule InpiChecker.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: InpiChecker.TaskSupervisor},
      InpiChecker.Session
    ]

    opts = [strategy: :one_for_one, name: InpiChecker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
