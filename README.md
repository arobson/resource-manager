# ResourceManager

A generic resource manager pool written in Elixir to demonstrate how to solve the general problem using a Supervisor and GenServer in OTP behing a simple API.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `resource_manager` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:resource_manager, "~> 0.1.0"}
  ]
end
```

### Import

```elixir
  import ResourceManager
```

## API

### Configuration
The recommended approach is to use the Hex configuration style, with a file per environment, as this library does. This will allow your application to provide a custom override for the configuration key, per environment like so:

```elixir
use Mix.Config
config(
  :resource_manager,
  :pool,
  %{
    minimum: 5,
    maximum: 10,
    factory: fn -> 
      #return your resouce here
    end
  }
)
```

The `:pool` key must provide a map with the following values:

 * `:maximum` - a limit for the maximum number of resources that the
  resource manager may create and lease at any give time 
 * `:minimum` - a limit for the least number of resources that the
  resource manager should have available at any given time
 * `:factory` - the 0 arity function to use to create new resources
  when initializing or expanding the pool

### Requesting

There are two blocking ways to request a resource from the pool:

#### getResource()

This approach will block indefinitely until a resource becomes available.

#### getResource(limit)

Using this call will only block until a resource is available or until the limit has been reached, in which case, an `{:empty, nil}` tuple will be returned.

### Releasing

The only way to return a resource to the pool is by calling `putResource`:

#### putResource(resource)

This returns the resource to the pool. In the event that enough resources are returned and the pool is under-utilized, the pool may begin to shrink back down toward a more balanced ideal to prevent idle over-utilization.

## Testing

After installing necessary dependencies via:

```shell
mix deps.get
```

You can run tests with:

```shell
mix test
```

## Interactive Testing

If you've installed the dependencies (See Testing above), then you can also start an interactive Elixir shell with the ResourceManager application running in the test environment using the following command:

```shell
iex -S mix
```

This will allow you to test the API interactively against `ResourceManager` as well as interact with the underlying GenServer itself.

## Documentation Generation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/resource_manager](https://hexdocs.pm/resource_manager).

