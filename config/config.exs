import Config

# Disable Swoosh API client in dev/test (it's an optional dep)
config :swoosh, :api_client, false

# Import environment specific config
import_config "#{config_env()}.exs"
