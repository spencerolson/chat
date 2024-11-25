defmodule Chat.Clustering do
  @loopback_address {127, 0, 0, 1}
  @super_secret_cookie :monster

  def setup do
    ensure_epmd_running()
  end

  def nodes() do
    [node() | Node.list()]
  end

  def get_node_name(str) do
    trimmed_str = String.trim(str)

    case String.split(trimmed_str, "@") do
      [_, _] -> str
      [name] when name != "" -> "#{name}@#{get_host()}"
      _ -> {:error, {:invalid_name, trimmed_str}}
    end
  end

  def start_node({:error, _} = error), do: error

  def start_node(node_name_str) do
    node_name = String.to_atom(node_name_str)

    case Node.start(node_name) do
      {:ok, _} ->
        Node.set_cookie(@super_secret_cookie)
        :net_kernel.monitor_nodes(true)
        {:ok, node_name_str}

      {:error, error} ->
        {:error, {:could_not_start, node_name_str, error}}
    end
  end

  def connect_node({:error, _} = error), do: error

  def connect_node(node_name_str) do
    node_name = String.to_atom(node_name_str)

    case Node.connect(node_name) do
      true ->
        {:ok, node_name_str}

      false ->
        {:error, {:could_not_connect, node_name_str}}

      :ignored ->
        {:error, {:must_login_first, node_name_str}}
    end
  end

  defp ensure_epmd_running do
    epmd_path = System.find_executable("epmd")
    if epmd_path do
      Port.open({:spawn_executable, epmd_path}, [])
      :ok
    else
      {:error, :epmd_not_found}
    end
  end

  defp get_host do
    {:ok, interfaces} = :inet.getifaddrs()
    Enum.find_value(interfaces, &interface_ipv4_addr/1)
  end

  defp interface_ipv4_addr({_, descriptions}) do
    flags = Keyword.get(descriptions, :flags, [])
    if Enum.member?(flags, :loopback) do
      nil
    else
      Enum.find_value(descriptions, &ipv4_addr/1)
    end
  end

  defp ipv4_addr({key, value}) do
    if key == :addr and tuple_size(value) == 4 and value != @loopback_address do
      value |> Tuple.to_list() |> Enum.join(".")
    end
  end
end
