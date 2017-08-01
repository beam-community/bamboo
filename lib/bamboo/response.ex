defmodule Bamboo.Response do
  @moduledoc """
  Response from an `adapter.deliver/2` call.
  """

  @type headers :: [{binary, binary}] | %{binary => binary}
  @type t :: %__MODULE__{
    status_code: number,
    headers: headers,
    body: binary
  }
  defstruct status_code: nil, headers: nil, body: nil

  @spec new_response(Enum.t) :: __MODULE__.t
  def new_response(attrs \\ []) do
    struct!(%__MODULE__{}, attrs)
  end

  @spec local_response() :: __MODULE__.t
  def local_response do
    new_response(status_code: 201, headers: %{}, body: some_body())
  end

  defp some_body, do: Poison.encode! %{id: "1", success: true, message: "email sent!"}
end
