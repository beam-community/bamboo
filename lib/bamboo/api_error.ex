defmodule Bamboo.ApiError do
  @moduledoc """
  Error used to represent a problem when sending emails through an external email service API.
  """

  defexception [:message]

  @doc """
  Raises an `ApiError` with the given `message` or `service_name`, `response` and `params`.

  An extra error message can be added using a fourth parameter `extra_message`.

  ## Examples

      iex> raise_api_error("Error message")
      ** (Bamboo.ApiError) Error Message

      iex> raise_api_error(service_name, response, params)
      ** (Bamboo.ApiError) There was a problem sending the email through the <service_name> API.

      Here is the response:

      "<response>"

      Here are the params we sent:

      "<params>"

      iex> raise_api_error(service_name, response, params, extra_message)
      ** (Bamboo.ApiError) There was a problem sending the email through the <service_name> API.

      Here is the response:

      "<response>"

      Here are the params we sent:

      "<params>"

      <extra_message>
  """
  def raise_api_error(message), do: raise(__MODULE__, message: message)

  def raise_api_error(service_name, response, params, extra_message \\ "") do
    message = """
    There was a problem sending the email through the #{service_name} API.

    Here is the response:

    #{inspect(response, limit: 150)}

    Here are the params we sent:

    #{inspect(params, limit: 150)}
    """

    message =
      case extra_message do
        "" -> message
        em -> message <> "\n#{em}\n"
      end

    raise(__MODULE__, message: message)
  end
end
