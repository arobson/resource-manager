use Mix.Config
config(
  :resource_manager,
  :pool,
  %{
    minimum: 2,
    maximum: 4,
    factory: fn -> {:ok, "test"} end
  }
)
