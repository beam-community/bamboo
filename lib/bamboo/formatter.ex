defprotocol Bamboo.Formatter do
  @moduledoc ~S"""
  Converts data to email addresses.

  The passed in options is currently a map with the key `:type` and a value of
  `:from`, `:to`, `:cc` or `:bcc`. This makes it so that you can pattern match
  and return a different address depending on if the address is being used in
  the from, to, cc or bcc.

  ## Simple example

  Let's say you have a user struct like this.

      defmodule MyApp.User do
        defstruct first_name: nil, last_name: nil, email: nil
      end

  Bamboo can automatically format this struct if you implement the Bamboo.Formatter
  protocol.

      defimpl Bamboo.Formatter, for: MyApp.User do
        # Used by `to`, `bcc`, `cc` and `from`
        def format_email_address(user, _opts) do
          fullname = "#{user.first_name} #{user.last_name}"
          {fullname, user.email}
        end
      end

  Now you can create emails like this, and the user will be formatted correctly

      user = %User{first_name: "John", last_name: "Doe", email: "me@example.com"}
      Bamboo.Email.new_email(from: user)

  ## Customize formatting based on from, to, cc or bcc

  This can be helpful if you want to add the name of the app when sending on
  behalf of a user.

      defimpl Bamboo.Formatter, for: MyApp.User do
        # Include the app name when used in a from address
        def format_email_address(user, %{type: :from}) do
          fullname = "#{user.first_name} #{user.last_name}"
          {fullname <> " (Sent from MyApp)", user.email}
        end

        # Just use the name for all other types
        def format_email_address(user, _opts) do
          fullname = "#{user.first_name} #{user.last_name}"
          {fullname, user.email}
        end
      end
  """

  @doc ~S"""
  Receives data and opts and should return a string or a 2 item tuple {name, address}

  opts is a map with the key `:type` and a value of
  `:from`, `:to`, `:cc` or `:bcc`. You can pattern match on this to customize
  the address.
  """

  @type opts :: %{type: :from | :to | :cc | :bcc}

  @spec format_email_address(any, opts) :: Bamboo.Email.address
  def format_email_address(data, opts)
end

defimpl Bamboo.Formatter, for: List do
  def format_email_address(email_addresses, opts) do
    email_addresses |> Enum.map(&Bamboo.Formatter.format_email_address(&1, opts))
  end
end

defimpl Bamboo.Formatter, for: BitString do
  def format_email_address(email_address, _opts) do
    {nil, email_address}
  end
end

defimpl Bamboo.Formatter, for: Tuple do
  def format_email_address(already_formatted_email, _opts) do
    already_formatted_email
  end
end

defimpl Bamboo.Formatter, for: Map do
  def format_email_address(invalid_address, _opts) do
    raise ArgumentError, """
    The format of the address was invalid. Got #{inspect invalid_address}.

    Expected a string, e.g. "foo@bar.com", a 2 item tuple {name, address}, or
    something that implements the Bamboo.Formatter protocol.

    Example:

    defimpl Bamboo.Formatter, for: MyApp.User do
      def format_email_address(user, _opts) do
        {user.name, user.email}
      end
    end
    """
  end
end
