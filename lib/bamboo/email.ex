defmodule Bamboo.Email do
  @moduledoc """
  Contains functions for creating emails.

  Bamboo separates composing emails from delivering them. This separation emails
  easy to test and makes things like using a default layout, or a default from
  address easy to do. This module is for creating emails. To actually send them,
  use [Bamboo.Mailer](Bamboo.Mailer.html).

  The from, to, cc and bcc addresses accept a string, a 2 item tuple
  {name, address}, or anything else that you create that implements the
  Bamboo.Formatter protocol. The to, cc and bcc fields can also accepts a list
  of any combination of strings, 2 item tuples or anything that
  implement the Bamboo.Formatter protocol. See
  [Bamboo.Formatter](Bamboo.Formatter.html) for more info.

  ## Simplest way to create a new email

  ```
  defmodule MyApp.Email do
    import Bamboo.Email

    def welcome_email(user) do
      new_email(
        from: "me@app.com",
        to: user,
        subject: "Welcome!",
        text_body: "Welcome to the app",
        html_body: "<strong>Welcome to the app</strong>"
      )
    end
  end
  ```

  ## Using functions to extract common parts

  Let's say you want all emails to have the same from address. Here's how you
  could do that

  ```
  defmodule MyApp.Email do
    import Bamboo.Email

    def welcome_email(user) do
      struct!(base_email,
        to: user,
        subject: "Welcome!",
        text_body: "Welcome to the app",
        html_body: "<strong>Welcome to the app</strong>"
      )

      # or you can use functions to build it up step by step

      base_email
      |> to(user)
      |> subject("Welcome!")
      |> text_body("Welcome to the app")
      |> html_body("<strong>Welcome to the app</strong>")
    end

    def base_email do
      new_email(from: "me@app.com")
    end
  end
  ```
  """

  defstruct from: nil,
      to: nil,
      cc: nil,
      bcc: nil,
      subject: nil,
      html_body: nil,
      text_body: nil,
      headers: %{},
      assigns: %{},
      private: %{}

  alias Bamboo.Email

  @attribute_pipe_functions ~w(from to cc bcc subject text_body html_body)a

  @doc """
  Used to create a new email

  If called without arguments it is the same as creating an empty
  `%Bamboo.Email{}` struct. If called with arguments it will populate the struct
  with given attributes.

  ## Example

      # Same as %Bamboo.Email{from: "support@myapp.com"}
      new_email(from: "support@myapp.com")
  """
  def new_email(attrs \\ []) do
    struct!(%__MODULE__{}, attrs)
  end

  for function_name <- @attribute_pipe_functions do
    @doc """
    Sets the #{function_name} on the email
    """
    def unquote(function_name)(email, attr) do
      Map.put(email, unquote(function_name), attr)
    end
  end

  @doc """
  Adds a header to the email

  ## Example

      put_header(email, "Reply-To", "support@myapp.com")
  """
  def put_header(%__MODULE__{headers: headers} = email, header_name, value) do
    %{email | headers: Map.put(headers, header_name, value)}
  end

  @doc """
  Adds a key/value to the private key of the email

  This is mostly used to implement specific functionality for a particular
  adapter. It will rarely be used directly from your code. Internally this is
  used to set Mandrill specific params for the Mandrill Adapter and it's also
  used to store the view module, template and layout when using Bamboo.Phoenix.

  ## Example

      put_private(email, :tags, "welcome-email")
  """
  def put_private(%Email{private: private} = email, key, value) do
    %{email | private: Map.put(private, key, value)}
  end
end
