defmodule ResourceManager do
  @moduledoc """
  Documentation for ResourceManager.
  """

  @doc """
  Presents a public API for the Resource Manager library application.
  This library behaves like a resource pool with the following qualities:
   * it is generic in nature and can be used to pool any resource type
   * it prints the current pool usage (free/used/waiting) every 15 seconds
   * min and max pool size are configurable paramters
   * the pool is automatically initialized to the minimum size
   * the pool expands when the usage increases over 60%
   * the pool shrinks when the usage decreases below 50%
   * expansion and shrinking have neglible impact on performance of getResource and putResource calls

   API
    * getResource() - block indefinitely while waiting for a resource from the pool
    * getResource(waitTime) - milliseconds to wait for a resource from the pool
    * putResource(resource) - returns a resource to the pool
  """

  def getResource() do
    GenServer.call(:resource_pool, :get_resource, :infinity)
  end

  def getResource(wait) do
    GenServer.call(:resource_pool, {:get_resource, wait}, :infinity)
  end

  def putResource(resource) do
    GenServer.call(:resource_pool, {:return_resource, resource})
  end

  def getStatus() do
    GenServer.call(:resource_pool, :status)
  end
end
