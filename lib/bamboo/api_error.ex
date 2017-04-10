defmodule Bamboo.ApiError do
  @moduledoc """
  Error used to represent a problem when sending emails through an external email service API.
  """

  defexception [:message]

  def raise_api_error(message), do: raise(__MODULE__, message: message)
  def raise_api_error(adapter, response, params, extra_message \\ "") when is_atom(adapter) do
    message = """
    There was a problem sending the email through the #{adapter_name(adapter)} API.

    Here is the response:

    #{inspect response, limit: :infinity}

    Here are the params we sent:

    #{inspect params, limit: :infinity}
    
    #{extra_message}
    """

    raise(__MODULE__, message: message)
  end

  defp adapter_name(adapter) do
    adapter
    |> Atom.to_string
    |> String.split(".")
    |> List.last
    |> String.replace_trailing("Adapter", "")
  end
end
