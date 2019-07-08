defmodule ResourceManagerTest do
  use ExUnit.Case
  doctest ResourceManager

  test "should have initialized to minimum" do
    assert ResourceManager.getStatus() == %{used: 0, free: 2, pool_size: 2, waiting: 0}
  end

  test "when retrieving resources should grow to limit and shrink to minimum" do
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getStatus() == %{used: 1, free: 1, pool_size: 1, waiting: 0}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getStatus() == %{used: 2, free: 1, pool_size: 1, waiting: 0}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getStatus() == %{used: 3, free: 1, pool_size: 1, waiting: 0}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 0}
    # returns resources back to the pool
    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    assert ResourceManager.getStatus() == %{used: 0, free: 2, pool_size: 2, waiting: 0}
  end

  test "when at max pool size, should wait until timeout or until returned resource" do
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getResource() == {:ok, "test"}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 0}
    task1 = Task.async(fn () -> ResourceManager.getResource() end)
    task2 = Task.async(fn () -> ResourceManager.getResource() end)
    task3 = Task.async(fn () -> ResourceManager.getResource(100) end)
    task4 = Task.async(fn () -> ResourceManager.getResource(10000) end)
    Process.sleep(100) # allows enough time for each async task to request new resource
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 4}

    #task3 will timeout and return the expected response
    assert Task.await(task3) == {:empty, nil}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 3}

    # return a resource and check for expected resolution
    Task.start(fn () ->
      Process.sleep(100)
      ResourceManager.putResource({:ok, "test1"})
    end)
    assert Task.await(task1, 200) == {:ok, "test1"}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 2}

    # return a resource and check for expected resolution
    Task.start(fn () ->
      Process.sleep(100)
      ResourceManager.putResource({:ok, "test2"})
    end)
    assert Task.await(task2, 200) == {:ok, "test2"}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 1}

    # return a resource and check for expected resolution
    Task.start(fn () ->
      Process.sleep(100)
      ResourceManager.putResource({:ok, "test3"})
    end)
    assert Task.await(task4, 200) == {:ok, "test3"}
    assert ResourceManager.getStatus() == %{used: 4, free: 0, pool_size: 0, waiting: 0}

    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    ResourceManager.putResource({:ok, "test"})
    assert ResourceManager.getStatus() == %{used: 0, free: 2, pool_size: 2, waiting: 0}
  end
end
