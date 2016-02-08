# Bamboo

A library for handling emails. Makes testing easy as well.

**This code in the README may be out of date.** See the tests directory for example of how to use Bamboo

## Usage

Bamboo breaks email creation and email sending in to two separate modules. To
begin, let's create a mailer that uses Mandrill as the backend.

```elixir
# In your config/config.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key"

# In your application code
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end

defmodule MyApp.Emails do
  import Bamboo.Email

  def welcome_email do
    new_mail(
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
  # Adds a `render` function for rending emails with Phoenix views
  use Bamboo.Phoenix, view: MyApp.EmailView
  import Bamboo.MandrillEmails

  def welcome_email do
    base_email
    |> to("foo@bar.com", %Bamboo.EmailAddress{name: "John Smith", address:"john@foo.com"})
    |> cc(author) # You can set up a custom protocol that handles different types of structs.
    |> subject("Welcome!!!")
    |> tag("welcome-email") # Imported by Bamboo.MandrillEmails
    |> put_header("Reply-To", "somewhere@example.com")
    # Uses the view from `view` to render the `welcome_email.html.eex`
    # and `welcome_email.text.eex` templates with the passed in assigns
    # Use string to render a specific template, e.g. `welcome_email.html.eex`
    |> render(:welcome_email, author: author)
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
  def format_email_address(user) do
    fullname = "#{user.first_name} #{user.last_name}"
    %Bamboo.EmailAddress{name: fullname, email: email}
  end
end
```

## In development (not started yet)

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
# Use the Bamboo.LocalAdapter in your config/test.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.LocalAdapter

# In your test
defmodule MyApp.EmailsTest do
  use ExUnit.Case

  alias MyApp.Emails

  test "welcome email" do
    user = %User{...}
    email = Emails.welcome_email(user)

    assert email.to == "someone@foo.com"
    assert email.subject == "This is your welcome email"
    assert email.html_body =~ "Welcome to the app!"
  end
end

# integration tests

defmodule MyApp.RegistrationControllerTest do
  use ExUnit.Case

  use Bamboo.Test
  alias MyApp.Emails

  test "registers user and sends welcome email" do
    ...post to registration controller

    newly_created_user = Repo.first(User)
    assert_delivered_email Emails.welcome_email(newly_created_user)
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
