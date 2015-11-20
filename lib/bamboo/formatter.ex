defprotocol Bamboo.Formatter do
  def format_recipient(email)
end

defimpl Bamboo.Formatter, for: BitString do
  def format_recipient(email_address) do
    %{name: nil, address: email_address}
  end
end

defimpl Bamboo.Formatter, for: Map do
  def format_recipient(%{name: _, address: _} = already_formatted) do
    already_formatted
  end

  def format_recipient(invalid_address) do
    raise ArgumentError, """
    The format of the address was invalid. Got #{inspect invalid_address}, expected a
    binary string or a map: "foo@bar.com" or %{name: "Foo", address: "bar@example.com"}
    """
  end
end
