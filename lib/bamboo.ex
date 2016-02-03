defmodule Bamboo do
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

  def start(_type, _args), do: Bamboo.SentEmail.start_link
end
