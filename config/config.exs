import Config

config :inpi_checker,
  base_url: "https://busca.inpi.gov.br/pePI",
  request_timeout: 60_000,
  max_retries: 3,
  initial_backoff: 2_000

import_config "#{config_env()}.exs"
