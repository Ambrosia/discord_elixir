defmodule DiscordElixir.WebSocket.Handlers.Keepalive do
  defmodule State do
    defstruct [:interval, :tref, :ws_client_pid]
  end

  use GenEvent
  alias DiscordElixir.WebSocket.Client
  require Logger

  @ready_states ["READY", "RESUME"]

  def init([]) do
    Logger.debug("Keepalive handler started")
    {:ok, %State{}}
  end

  def handle_event({:connected, ws_client_pid}, state) do
    {:ok, %State{state | ws_client_pid: ws_client_pid}}
  end

  def handle_event({:message, msg = %{"t" => event_type}}, state)
  when event_type in @ready_states do
    Logger.debug("READY or RESUME event received")
    %{"d" => %{"heartbeat_interval" => interval}} = msg
    {:ok, handle_heartbeat(interval, state, state.ws_client_pid)}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  defp handle_heartbeat(same, state = %State{interval: same}, _) do
    state
  end

  defp handle_heartbeat(new_interval, state, ws_client_pid) do
    Logger.debug("New heartbeat interval detected")
    {:ok, tref} = new_timer(new_interval, ws_client_pid, state)
    %State{state | interval: new_interval, tref: tref}
  end

  defp new_timer(new_interval, ws_client_pid, state) do
    Logger.debug("New timer, sending keepalive every #{new_interval}ms")
    :timer.cancel(state.tref)
    {:ok, tref} = :timer.apply_interval(new_interval,
                                        __MODULE__,
                                        :send_keepalive,
                                        [ws_client_pid])
  end

  def send_keepalive(ws_client_pid) do
    Logger.debug("Sending keepalive")
    Client.cast(ws_client_pid, keepalive_msg)
  end

  defp keepalive_msg do
    %{op: 1,
      d: time}
    |> Poison.encode!
  end

  defp time, do: :os.system_time(:milli_seconds)
end
