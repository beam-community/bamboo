defmodule Bamboo do
  @moduledoc false

  use Application

  defmodule EmptyFromAddressError do
    defexception [:message]

    def exception(_) do
      %EmptyFromAddressError{
        message: """
        The from address was empty. Set an address as a string, a Bamboo.EmailAddress
        struct, or with a struct that implements the Bamboo.Formatter protocol.
        """
      }
    end
  end

  defmodule NilRecipientsError do
    defexception [:message]

    def exception(email) do
      message = """
      All recipients were set to nil. Must specify at least one recipient.

      Full email - #{inspect email, limit: :infinity}
      """
      %NilRecipientsError{message: message}
    end
  end

  def start(_type, _args), do: Bamboo.SentEmail.start_link
end
