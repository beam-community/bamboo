defmodule Bamboo.EmailAddress do
  @moduledoc """
  A struct used for building email addresses.

  There are two keys, `name` and `address`. You can use this struct in the
  `from`, `to`, `cc` and `bcc` fields. This struct is also used when
  implementing custom formatter using the
  [Bamboo.Formatter](Bamboo.Formatter.html) protocol.

  ## Examples

      Bamboo.Email.new_email(
        from: %Bamboo.EmailAddress{name: "MyApp", address: "support@myapp.com"},
      )
  """

  defstruct name: nil, address: nil
end
