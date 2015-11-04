# Bamboo

A library for handling emails. Makes testing easy as well.

**This code in the README is just a proof of concept.** Once I like how it looks I
will actually write the code. Don't be surprised that there is no code here yet.

## Usage

Bamboo breaks email creation and email sending in to two separate modules. To
begin, let's create a mailer that uses Mandrill as the backend.

```elixir
# In your config/config.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.Mandrill,
  api_key: "my_api_key"

# In your application code
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end

defmodule MyApp.Emails do
  use Bamboo.Email

  def welcome_email do
    mail(
      to: "foo@example.com",
      from: "me@example.com",
      subject: "Welcome!!!",
      html_body: "<strong>WELCOME</strong>",
      text_body: "WELCOME"
    )
  end
end

# In a controller or some other module
defmodule MyApp.Foo do
  alias MyApp.Emails
  alias MyApp.Mailer

  def register_user do
    # Create a user and whatever else is needed
    Emails.welcome_email |> Mailer.deliver
  end
end
```

## More options

```elixir
defmodule MyApp.Emails do
  use Bamboo.Phoenix, render_with: MyApp.EmailView
  import Bamboo.MandrillEmails

  def welcome_email do
    base_email
    # Bulk update the email
    |> struct(bcc: "someone@bar.com", from: "other_person@foo.com")
    |> to("foo@bar.com", ["John Smith": "john@foo.com"])
    |> cc(author) # You can set up a custom protocol that handles different types of structs.
    |> subject("Welcome!!!")
    |> tag("welcome-email") # Imported by Bamboo.MandrillEmails
    |> put_header("Reply-To", "somewhere@example.com")
    # Uses the view from `render_with` to render the `welcome_email.html.eex`
    # and `welcome_email.text.eex` templates with the passed in assigns
    |> render("welcome_email", author: author)
  end

  defp author do
    User |> Repo.one
  end

  defp base_email do
    mail(from: "myapp@example.com")
  end
end

defimpl Bamboo.Formatter, for: User do
  # Used by `to`, `bcc`, `cc` and `from`
  def extract_email(%User{email: email, name: name}) do
    [name => email]
  end
end
```

## In development

You can see the sent emails by forwarding a route to the `Bamboo.Preview`
module. You can see all the emails sent. It will live update with new emails
sent.

```elixir
# In your Phoenix router
forward "/delivered_emails", Bamboo.Mailbox

# If you want to see the latest email, add this to your socket
channel "/latest_email", Bamboo.LatestEmailChannel

# In your browser
localhost:4000/email_previews
```

## Testing

You can use the `Bamboo.TestAdapter` to make testing your emails a piece of cake.

```elixir
# Use the Bamboo.TestAdapter in your config/test.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.TestAdapter

# In your test
defmodule MyApp.MailerTest do
  use ExUnit.Case

  alias MyApp.Emails
  alias MyApp.Mailer
  alias Bamboo.Mailbox

  test "sends a welcome email" do
    Emails.welcome_email |> Mailer.deliver

    email = TestMailbox.deliveries |> List.first
    # or use TestMailbox.one which will raise if there is anything but one email
delivered
    assert email.to == "someone@foo.com"
    assert email.subject == "This is your welcome email"
    assert email.html_body =~ "Welcome to the app!"
  end
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add bamboo to your list of dependencies in `mix.exs`:

        def deps do
          [{:bamboo, "~> 0.0.1"}]
        end

  2. Ensure bamboo is started before your application:

        def application do
          [applications: [:bamboo]]
        end
