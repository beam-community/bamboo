defmodule Bamboo.ApiError do
  @moduledoc """
  Error used to represent a problem when sending emails through an external email service API.
  """

  defexception [:message]
end
