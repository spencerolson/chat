defmodule Chat.Messaging do
  @system_message_start "<<"
  @system_message_end ">>"

  # -- Login/Logout --

  def logged_in(node_name) do
    system_message("#{node_name} logged in")
  end

  def connected(node_name) do
    system_message("#{node_name} connected to the cluster")
  end

  def logged_out(node_name) do
    system_message("#{node_name} logged out")
  end

  def failed_logout do
    system_message("Failed to logout")
  end

  def requires_login do
    system_message("Must login first. Type 'help' for more info")
  end

  def disconnected(node_name), do: logged_out(node_name)

  # -- Colors --

  def color_changed(color) do
    system_message("Color changed to #{color}")
  end

  def invalid_color do
    system_message("Invalid color code. Please enter a number between 0 and 255, inclusive")
  end

  # -- Users --

  def userlist_title do
    "\r\nConnected Users:\r\n"
  end

  def userslist_line(node) do
    "- #{node}#{if Node.self() == node, do: " (you)", else: ""}\r\n"
  end

  # -- Clustering --

  def could_not_connect_node(node_name) do
    system_message("Failed to connect to node with name #{node_name}")
  end

  def could_not_start_node(node_name) do
    system_message("Failed to start node with name #{node_name}")
  end

  def invalid_node_name("") do
    system_message("Login cannot be empty. Please enter a valid name")
  end

  def invalid_node_name(node_name) do
    system_message("Invalid login #{node_name}. Please enter a valid name")
  end

  # -- Help --

  def help_message do
    """
    Commands:\r
    help - show this message.\r

    login <name>@<host> - login to the chat with name and host.\r
    login <name> - login to the chat with name. Tries to infer host from `ipconfig getifaddr en0`.\r

    connect <name>@<host> - connect to another user. Connecting to a single user automatically connects to all users in the cluster.\r
    connect <name> - connect to another user with the same host.\r

    users - list connected users.\r

    color <color code> - set the color of your messages. Color code is an integer between 0 and 255, inclusive.\r
    color rand - set the color of your messages to a random color.\r

    logout - logout from the chat.\r
    """
  end

  # -- Utils --

  defp system_message(text) do
    "#{@system_message_start} #{text} #{@system_message_end}"
  end
end
