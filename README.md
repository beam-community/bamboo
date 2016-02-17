# Bamboo

Flexible and easy to use email for Elixir.

* Adapter based so it can be used with Mandrill, SMTP, or whatever else you want. Comes with a Mandrill adapter out of the box.
* Easy to format recipients. You can do `new_email(to: Repo.one(User))` and Bamboo can format the user automatically.
* Works out of the box with Phoenix. Use views and layouts to make rendering email easy.
* Very composable. Emails are just a Bamboo.Email struct and be manipulated with plain functions.
* Easy to unit test. Because delivery is separated from email creation, no special functions are needed, just assert against fields on the email.
* Easy to test delivery in integration tests. As little repeated code as possible.

See the module docs for the most up to date information.

## Usage

Bamboo breaks email creation and email sending in to two separate modules.

```elixir
# In your config/config.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key"

# Somewhere in your application
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end

# Define your emails
defmodule MyApp.Emails do
  import Bamboo.Email

  def welcome_email do
    new_mail(
      to: "foo@example.com",
      from: "me@example.com",
      subject: "Welcome!!!",
      html_body: "<strong>Welcome</strong>",
      text_body: "welcome"
    )
  end
end

# In a controller or some other module
defmodule MyApp.Foo do
  alias MyApp.Emails
  alias MyApp.Mailer

  def register_user do
    # Create a user and whatever else is needed

    # Emails are not delivered until you explicitly deliver them.
    Emails.welcome_email |> Mailer.deliver
  end
end
```

## Composing with pipes. Use for default from address, default layouts, etc.

```elixir
defmodule MyApp.Emails do
  # Adds a `render` function for rending emails with a Phoenix view
  use Bamboo.Phoenix, view: MyApp.EmailView
  import Bamboo.MandrillEmails

  def welcome_email do
    base_email
    # Emails addresses can be a string
    |> to("foo@bar.com")
    # or a 2 item tuple
    |> bcc({"John Smith", "john@gmail.com"})
    # or you can set up a custom protocol that handles different types of structs.
    |> cc(author_from_db())
    |> subject("Welcome!!!")
    # Imported by Bamboo.MandrillEmails
    |> tag("welcome-email")
    |> put_header("Reply-To", "somewhere@example.com")
    # Uses the view from `use Bamboo.Phoenix, view: View` to render the `welcome_email.html.eex`
    # and `welcome_email.text.eex` templates with the passed in assigns.
    # Use a string to render a specific template, e.g. `welcome_email.html.eex`
    |> render(:welcome_email, author: author)
  end

  defp author_from_db do
    User |> Repo.one
  end

  defp base_email do
    # Set a default from, default headers, etc.
    mail(from: "myapp@example.com")
  end
end

defimpl Bamboo.Formatter, for: User do
  # Used by to, bcc, cc and from
  def format_email_address(user, _opts) do
    fullname = "#{user.first_name} #{user.last_name}"
    {fullname, user.email}
  end
end
```

## In development (coming soonish)

You can see the sent emails by forwarding a route to the `Bamboo.Preview`
module. You can see all the emails sent. It will live update with new emails
sent.

```elixir
# In your Phoenix router
forward "/delivered_emails", Bamboo.SentEmailController

# In your browser
localhost:4000/delivered_emails
```

## Testing

You can use the `Bamboo.TestAdapter` to make testing your emails a piece of cake.
See documentation for `Bamboo.Test` for more examples.

```elixir
# Use the Bamboo.TestAdapter in your config/test.exs file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.TestAdapter

# Unit testing requires no special functions
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

# Integration tests

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

To use the latest from master.

  1. Add bamboo to your list of dependencies in `mix.exs`:

        def deps do
          [{:bamboo, github: "paulcsmith/bamboo"}]
        end

  2. Ensure bamboo is started before your application:

        def application do
          [applications: [:bamboo]]
        end

  3. Add the the Bamboo.TaskSupervior as a child to your supervisor

  ```elixir
  # Usually in lib/my_app_name/my_app_name.ex
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # Add the supervisor that handles deliver_later calls
      Bamboo.TaskSupervisorStrategy.child_spec
    ]

    # This part is usually already there.
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```
