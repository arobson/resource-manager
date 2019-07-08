use Mix.Config
config(
  :resource_manager,
  :pool,
  %{
    minimum: 5,
    maximum: 20,
    factory: fn -> nil end
  }
)
