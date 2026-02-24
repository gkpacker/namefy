import Config

# Load .env file if it exists
if File.exists?(".env") do
  Dotenvy.source!(".env")
end

config :inpi_checker,
  inpi_user: System.get_env("INPI_USER"),
  inpi_password: System.get_env("INPI_PASSWORD")
