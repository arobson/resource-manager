defmodule ResourceManager.Worker do
  use GenServer

  @doc """
  A GenServer that behaves like a simple resource pool with the following characteristics:
   * can be used to pool any resource type
   * min pool & max pool size are configurable
   * the pool is initialized with the minimum number of resources
   * the pool grows when the usage increases above 60%
   * the pool shrinks when the usage drops below 50%
   * expansion and shrinking actions should not add latency or block getResource() and putResource() calls.
   * prints the current pool usage (free/used/waiting) every 15 seconds

  Handles the following messages:
   :get_resource -> returns a resource to the caller
      If no resource is available in the pool this method blocks indefinitely by returning an
      immediate :noreply and adding the caller's pid to a waiting list stored in state by UUID
    {:getResource, waitTime} –> return a resource to the caller within a waitTime
      The call will block until:
        * a resource is or becomes available in the pool
        * the waitTime is exceeded
      {:empty, nil} is returned in the event the waitTime is past

    {:return_resource, resource} -> returns the resource back to the pool
      returns {:ok, pool_depth} to the caller
    :status -> returns the map %{used: 0, free: 0, pool_size: 0, waiting: 0}
      primarily for test purposes

  ## Examples

    iex> ResourceManager.Worker.fill_pool(fn () -> "test" end, 4)
    [ "test", "test", "test", "test" ]

    iex> ResourceManager.Worker.join(3, %{minimum: 2, maximum: 4, factory: nil, pool: [1, 2], free: 2, used: 1, waiting: []})
    %{minimum: 2, maximum: 4, factory: nil, pool: [1, 2], free: 2, used: 0, waiting: []}
  """

  @impl true
  def init(%{minimum: min, maximum: max, factory: f}) do
    state = %{minimum: min, maximum: max, factory: f, free: min, used: 0, pool: fill_pool(f, min), waiting: []}
    schedule_log()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_resource, from, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w}) do
    case p do
      [] ->
        {:noreply, %{minimum: min, maximum: max, factory: f, pool: [], free: fr, used: u, waiting: [{from, UUID.uuid1()}|w]}}
      [h] ->
        {:reply, h, add(%{minimum: min, maximum: max, factory: f, pool: [], free: fr, used: u, waiting: w})}
      [h|t] ->
        {:reply, h, add(%{minimum: min, maximum: max, factory: f, pool: t, free: fr, used: u, waiting: w})}
    end
  end

  @impl true
  def handle_call({:get_resource, wait}, from, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w}) do
    case p do
      [] ->
        id = UUID.uuid1()
        handle_timeout(id, wait)
        {:noreply, %{minimum: min, maximum: max, factory: f, pool: [], free: fr, used: u, waiting: [{from, id}|w]}}
      [h] ->
        {:reply, h, add(%{minimum: min, maximum: max, factory: f, pool: [], free: fr, used: u, waiting: w})}
      [h|t] ->
        {:reply, h, add(%{minimum: min, maximum: max, factory: f, pool: t, free: fr, used: u, waiting: w})}
    end
  end

  def handle_call({:return_resource, r}, _from, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w}) do
    case w do
      [] ->
        {:reply, {:ok, Enum.count(p) + 1}, join(r, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w})}
      [{client, _id}] ->
        GenServer.reply(client, r)
        {:reply, {:ok, Enum.count(p)}, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: []}}
      [{client, _id}|wt] ->
        GenServer.reply(client, r)
        {:reply, {:ok, Enum.count(p)}, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: wt}}
    end
  end

  def handle_call(:status, _from, %{pool: p, free: fr, used: u, waiting: w} = state) do
    {:reply, %{free: fr, used: u, waiting: Enum.count(w), pool_size: Enum.count(p)}, state}
  end

  @impl true
  def handle_info(:log_status, %{free: f, used: u, waiting: w} = state) do
    IO.puts(:stdio, "free: #{f}\t\tused: #{u}\t\twaiting: #{Enum.count(w)}")
    schedule_log()
    {:noreply, state}
  end

  @impl true
  def handle_info({:timeout, id}, %{waiting: w} = state) do
    {{client, _}, list} = get_waiting(id, w)
    GenServer.reply(client, {:empty, nil})
    newState = Map.put(state, :waiting, list)
    {:noreply, newState}
  end

  @spec start_link(map) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(init_arg) do
    GenServer.start_link(ResourceManager.Worker, init_arg, [name: :resource_pool])
  end

  @spec fill_pool(fun, number) :: list
  def fill_pool(factory, count) do
    Enum.map(1..count, fn _x -> factory.() end)
  end

  def schedule_log() do
    Process.send_after(:resource_pool, :log_status, 15000)
  end

  def handle_timeout(id, timeout) do
    Process.send_after(:resource_pool, {:timeout, id}, timeout)
  end

  def available(total, maximum) do
    if total < maximum do
      true
    else
      false
    end
  end

  def grow(usage) do
    if usage > 0.6 do
      true
    else
      false
    end
  end

  def shrink(usage) do
    if usage < 0.5 do
      true
    else
      false
    end
  end

  def sufficient(total, minimum) do
    if total > minimum do
      true
    else
      false
    end
  end

  def add(%{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w}) do
    used = u + 1
    free = fr - 1
    total = used + free
    usage = used / total
    go = available(total, max) && grow(usage)
    if go do
      new = f.()
      %{minimum: min, maximum: max, factory: f, pool: [new|p], free: fr, used: used, waiting: w}
    else
      %{minimum: min, maximum: max, factory: f, pool: p, free: free, used: used, waiting: w}
    end
  end

  def join(r, %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: u, waiting: w}) do
    used = u - 1
    total = u + fr
    usage = used / total
    go = sufficient(total, min) && shrink(usage)
    if go do
      %{minimum: min, maximum: max, factory: f, pool: p, free: fr, used: used, waiting: w}
    else
      p2 = [r|p]
      %{minimum: min, maximum: max, factory: f, pool: p2, free: Enum.count(p2), used: used, waiting: w}
    end
  end

  def get_waiting(id, waiting) do
    Enum.reduce(waiting, {nil, []}, fn({from, i}, {match, list}) ->
      if i == id do
        {{from, i}, list}
      else
        {match, [{from, i}|list]}
      end
    end)
  end
end
