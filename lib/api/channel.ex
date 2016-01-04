defmodule DiscordElixir.API.Channel do
  @moduledoc """
  Discord's Channel API.

  If a token is stored using `API.Token`, all `token` arguments
  are optional.
  """

  defstruct guild_id: nil, id: nil, is_private: false,
  last_message_id: nil, name: nil, permission_overwrites: [], position: nil,
  topic: nil, type: nil

  alias DiscordElixir.API
  alias DiscordElixir.API.{Guild, Token}
  alias __MODULE__, as: Channel

  @doc """
  Creates a channel inside the given guild.

  - `guild` can either be a `Guild` or guild id.
  - `params` is a map with the values of `name` and `type`.
    These are both required.
    - `name` must be a string 2-100 characters long.
    - `type` must either be `:text` or `:voice`.
      This is optional.
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.create(guild, %{name: "channel", type: :text})
      {:ok, API.Channel{...}}
  """
  def create(guild, params, token \\ nil) do
    name = Map.get(params, :name)
    type = Map.get(params, :type, :text)

    url = Guild.guild_url(guild) <> "/channels"
    headers = API.token_header(token)

    with :ok <- validate_channel_name(name),
         :ok <- validate_channel_type(type),
         {:ok, response} <- API.post(url, params, headers),
         do: {:ok, parse(response.body)}
  end

  @doc """
  Creates a channel inside the given guild.

  - `guild` can either be a `Guild` or guild id.
  - `params` is a map with the values of `name` and `type`.
    These are both required.
    - `name` must be a string 2-100 characters long.
    - `type` must either be `:text` or `:voice`.
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.create!(guild, %{name: "channel", type: :text})
      API.Channel{...}
  """
  def create!(guild, params, token \\ nil) do
    case create(guild, params, token) do
      {:ok, channel} -> channel
      {:error, error = %HTTPoison.Error{}} -> raise error
      {:error, error} -> raise ArgumentError, Atom.to_string(error)
    end
  end

  @doc """
  Edits a channel's settings.

  - `channel` can either be a `Channel` struct or the channel's id (string).
  - `params` is a map with the values of `name`, `position` and `topic`.
    These params are only optional if a `Channel` struct is used.
    - `name` is the channel name to change to.
      Must be a string 2-100 characters long.
    - `position` is the position in the channel list to change to.
    Must be an int over -1.
    - `topic` is the topic to use for the channel. Must be a string.
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.edit(channel, %{name: "cool-kids"})
      {:ok, API.Channel{...}}
  """
  def edit(channel, params, token \\ nil)
  def edit(channel = %Channel{}, params, token) do
    params = params
    |> Map.put_new(:name, channel.name)
    |> Map.put_new(:position, channel.position)
    |> Map.put_new(:topic, channel.topic)

    edit(channel, params, token)
  end

  def edit(channel, params, token) do
    url = channel |> channel_url
    headers = API.token_header(token)

    with :ok <- validate_channel_name(params.name),
         :ok <- validate_channel_position(params.position),
         {:ok, response} <- API.patch(url, params, headers),
         do: {:ok, parse(response.body)}
  end

  @doc """
  Edits a channel's settings.

  - `channel` can either be a `Channel` struct or the channel's id (string).
  - `params` is a map with the values of `name`, `position` and `topic`.
    These params are only optional if a `Channel` struct is used.
    - `name` is the channel name to change to.
      Must be a string 2-100 characters long.
    - `position` is the position in the channel list to change to.
      Must be an int over -1.
    - `topic` is the topic to use for the channel. Must be a string.
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.edit!(channel, %{name: "cool-kids"})
      API.Channel{...}
  """
  def edit!(channel, params, token \\ nil) do
    case edit(channel, params, token) do
      {:ok, channel} -> channel
      {:error, error = %HTTPoison.Error{}} -> raise error
      {:error, error} -> raise ArgumentError, Atom.to_string(error)
    end
  end

  @doc """
  Deletes a channel.

  - `channel` can either be a `Channel` struct or the channel's id (string).
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.delete(channel)
      {:ok, API.Channel{...}}
  """
  def delete(channel, token \\ nil) do
    url = channel |> channel_url
    headers = API.token_header(token)

    with {:ok, response} <- API.delete(url, headers),
         do: {:ok, parse(response.body)}
  end

  @doc """
  Deletes a channel.

  - `channel` can either be a `Channel` struct or the channel's id (string).
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.delete!(channel)
      API.Channel{...}
  """
  def delete!(channel, token \\ nil) do
    case delete(channel, token) do
      {:ok, channel} -> channel
      {:error, error = %HTTPoison.Error{}} -> raise error
      {:error, error} -> raise ArgumentError, Atom.to_string(error)
    end
  end

  @doc """
  Broadcasts to a channel that this user is currently typing.

  The typing notification lasts for 5 seconds.

  - `channel` can either be a `Channel` struct or the channel's id (string).
  - `token` is the API token to use. This is optional if `API.Token` is used.

  ## Example

      iex> API.Channel.broadcast_typing(channel)
      :ok
  """
  def broadcast_typing(channel, token \\ nil) do
    url = channel |> channel_url
    headers = API.token_header(token)

    case API.post(url <> "/typing", :empty, headers) do
      {:ok, _response} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  def channel_url, do: "/channels"
  def channel_url(%Channel{id: id}), do: channel_url(id)
  def channel_url(channel_id), do: channel_url <> "/" <> to_string(channel_id)

  defp validate_channel_name(name) do
    if Regex.match?(~r/^[a-z0-9\-]{2,100}$/i, name) do
      :ok
    else
      {:error, :invalid_channel_name}
    end
  end

  defp validate_channel_type(type) when type in [:text, :voice], do: :ok
  defp validate_channel_type(_type), do: {:error, :invalid_channel_type}

  defp validate_channel_position(pos) when is_integer(pos) and pos >= -1, do: :ok
  defp validate_channel_position(_pos), do: {:error, :invalid_channel_position}

  def parse(channel) do
    channel = for {key, val} <- channel, into: %{} do
      {String.to_existing_atom(key), val}
    end
    Map.put_new(channel, :__struct__, Channel)
  end
end
