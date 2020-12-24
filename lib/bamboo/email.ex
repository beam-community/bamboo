defmodule Bamboo.Email do
  @moduledoc """
  Contains functions for composing emails.

  Bamboo separates composing emails from delivering them. This separation makes
  emails easy to test and makes things like using a default layout or a default
  from address easy to do. This module is for creating emails. To actually send
  them, use [Bamboo.Mailer](Bamboo.Mailer.html).

  ## Handling email addresses

  The from, to, cc, and bcc addresses of a `Bamboo.Email` can be set to any
  data structure for which there is an implementation of the
  [Bamboo.Formatter](Bamboo.Formatter.html) protocol or a list of such data
  structures. Bamboo includes implementations for some common data structures
  or you can create your own. All from, to, cc, and bcc addresses are
  normalized internally to a two item tuple of `{name, address}`. See
  [Bamboo.Formatter](Bamboo.Formatter.html) for more info.

  ## Simplest way to create a new email

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

  ## Extracting common parts (default layout, default from address, etc.)

  Let's say you want all emails to have the same from address. Here's how you
  could do that

      defmodule MyApp.Email do
        import Bamboo.Email

        def welcome_email(user) do
          # Since new_email/1 returns a struct you can update it with Kernel.struct!/2
          struct!(base_email(),
            to: user,
            subject: "Welcome!",
            text_body: "Welcome to the app",
            html_body: "<strong>Welcome to the app</strong>"
          )
        end

        def base_email do
          new_email(from: "me@app.com")
        end
      end

  In addition to keyword lists, `Bamboo.Email`s can also be built using function pipelines.

      defmodule MyApp.Email do
        import Bamboo.Email

        def welcome_email(user) do
          base_email()
          |> to(user)
          |> subject("Welcome!")
          |> text_body("Welcome to the app")
          |> html_body("<strong>Welcome to the app</strong>")
        end
      end
  """

  @type address :: {String.t(), String.t()}
  @type address_list :: nil | address | [address] | any

  @type t :: %__MODULE__{
          to: address_list,
          cc: address_list,
          bcc: address_list,
          subject: nil | String.t(),
          html_body: nil | String.t(),
          text_body: nil | String.t(),
          headers: %{String.t() => String.t()},
          assigns: %{atom => any},
          private: %{atom => any}
        }

  defstruct from: nil,
            to: nil,
            cc: nil,
            bcc: nil,
            subject: nil,
            html_body: nil,
            text_body: nil,
            headers: %{},
            attachments: [],
            assigns: %{},
            private: %{}

  alias Bamboo.{Email, Attachment}

  @address_functions ~w(from to cc bcc)a
  @attribute_pipe_functions ~w(subject text_body html_body)a

  @doc """
  Used to create a new email

  If called without arguments it is the same as creating an empty
  `%Bamboo.Email{}` struct. If called with arguments it will populate the struct
  with given attributes.

  ## Example

      # Same as %Bamboo.Email{from: "support@myapp.com"}
      new_email(from: "support@myapp.com")
  """
  @spec new_email(Enum.t()) :: __MODULE__.t()
  def new_email(attrs \\ []) do
    struct!(%__MODULE__{}, attrs)
  end

  for function_name <- @address_functions do
    @doc """
    Sets the `#{function_name}` on the email.

    `#{function_name}` receives as an argument any data structure for which
    there is an implementation of the [`Bamboo.Formatter`](Bamboo.Formatter.html) protocol.

        new_email()
        |> #{function_name}(["sally@example.com", "james@example.com"])
    """
    @spec unquote(function_name)(__MODULE__.t(), address_list) :: __MODULE__.t()
    def unquote(function_name)(email, attr) do
      Map.put(email, unquote(function_name), attr)
    end
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
  Returns a list of all recipients (to, cc and bcc).
  """
  @spec all_recipients(__MODULE__.t()) :: [address] | no_return
  def all_recipients(%Bamboo.Email{to: to, cc: cc, bcc: bcc} = email)
      when is_list(to) and is_list(cc) and is_list(bcc) do
    email.to ++ email.cc ++ email.bcc
  end

  def all_recipients(email) do
    raise """
    expected email with normalized recipients, got: #{inspect(email)}

    Make sure to call Bamboo.Mailer.normalize_addresses
    """
  end

  @doc """
  Gets just the email address from a normalized email address

  Normalized email addresses are 2 item tuples {name, address}. This gets the
  address part of the tuple. Use this instead of calling `elem(address, 1)`
  so that if Bamboo changes how email addresses are represented your code will
  still work

  ## Examples

      Bamboo.Email.get_address({"Paul", "paul@thoughtbot.com"}) # "paul@thoughtbot.com"
  """
  @spec get_address(address) :: String.t() | no_return
  def get_address({_name, address}), do: address

  def get_address(invalid_address) do
    raise "expected an address as a 2 item tuple {name, address}, got: #{inspect(invalid_address)}"
  end

  @doc """
  Adds a header to the email

  ## Example

      put_header(email, "Reply-To", "support@myapp.com")
  """
  @spec put_header(__MODULE__.t(), String.t(), String.t()) :: __MODULE__.t()
  def put_header(%__MODULE__{headers: headers} = email, header_name, value) do
    %{email | headers: Map.put(headers, header_name, value)}
  end

  @doc """
  Adds a key/value to the private key of the email

  This is mostly used to implement specific functionality for a particular
  adapter. It will rarely be used directly from your code. Internally this is
  used to set Mandrill specific params for the MandrillAdapter and it's also
  used to store the view module, template and layout when using Bamboo.Phoenix.

  ## Example

      put_private(email, :tags, "welcome-email")
  """
  @spec put_private(__MODULE__.t(), atom, any) :: __MODULE__.t()
  def put_private(%Email{private: private} = email, key, value) do
    %{email | private: Map.put(private, key, value)}
  end

  @doc ~S"""
  Adds a data attachment to the email

  ## Example

      put_attachment(email, %Bamboo.Attachment{})

  Requires the fields filename and data of the `%Bamboo.Attachment{}` struct to be set.

  ## Example

      def create(conn, params) do
        #...
        email
        |> put_attachment(%Bamboo.Attachment{filename: "event.ics", data: "BEGIN:VCALENDAR..."})
        #...
      end
  """
  def put_attachment(%__MODULE__{attachments: _}, %Attachment{filename: nil} = attachment) do
    raise "You must provide a filename for the attachment, instead got: #{inspect(attachment)}"
  end

  def put_attachment(%__MODULE__{attachments: _}, %Attachment{data: nil} = attachment) do
    raise "The attachment must contain data, instead got: #{inspect(attachment)}"
  end

  def put_attachment(%__MODULE__{attachments: attachments} = email, %Attachment{} = attachment) do
    %{email | attachments: [attachment | attachments]}
  end

  @doc ~S"""
  Adds a file attachment to the email

  ## Example

      put_attachment(email, path, opts \\ [])

  Accepts `filename: <name>` and `content_type: <type>` options.

  If you are using Plug, it accepts a Plug.Upload struct

  ## Example

      def create(conn, params) do
        #...
        email
        |> put_attachment(params["file"])
        #...
      end
  """
  def put_attachment(%__MODULE__{attachments: attachments} = email, path, opts \\ []) do
    %{email | attachments: [Bamboo.Attachment.new(path, opts) | attachments]}
  end
end
