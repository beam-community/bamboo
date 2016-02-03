defprotocol Bamboo.Formatter do
  def format_email_address(email, opts)
end

defimpl Bamboo.Formatter, for: List do
  def format_email_address(email_addresses, opts) do
    email_addresses |> Enum.map(&Bamboo.Formatter.format_email_address(&1, opts))
  end
end

defimpl Bamboo.Formatter, for: BitString do
  def format_email_address(email_address, _opts) do
    %Bamboo.EmailAddress{name: nil, address: email_address}
  end
end

defimpl Bamboo.Formatter, for: Bamboo.EmailAddress do
  def format_email_address(already_formatted_email, _opts) do
    already_formatted_email
  end
end

defimpl Bamboo.Formatter, for: Map do
  def format_email_address(invalid_address, _opts) do
    raise ArgumentError, """
    The format of the address was invalid. Got #{inspect invalid_address}.
    Expected a string, e.g. "foo@bar.com", or a Bamboo.EmailAddress struct.

    You can also implement a custom protocol for structs.

    Example:

    defimpl Bamboo.Formatter, for: MyApp.User do
      def format_email_address(user, _opts) do
        %Bamboo.EmailAddress{name: user.name, address: user.email}
      end
    end
    """
  end
end
