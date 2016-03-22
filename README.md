

Bamboo [![Circle CI](https://circleci.com/gh/paulcsmith/bamboo/tree/master.svg?style=svg)](https://circleci.com/gh/paulcsmith/bamboo/tree/master) [![Coverage Status](https://coveralls.io/repos/github/paulcsmith/bamboo/badge.png?branch=master)](https://coveralls.io/github/paulcsmith/bamboo?branch=master)
========

Flexible and easy to use email for Elixir.

* **Adapter based** so it can be used with Mandrill, SMTP, or whatever else you want. Comes with a Mandrill adapter out of the box.
* **Easy to format recipients**. You can do `new_email(to: Repo.one(User))` and Bamboo can format the User struct if you implement Bamboo.Formatter.
* **Works out of the box with Phoenix**. Use views and layouts to make rendering email easy.
* **Very composable**. Emails are just a Bamboo.Email struct and be manipulated with plain functions.
* **Easy to unit test**. Because delivery is separated from email creation, no special functions are needed, just assert against fields on the email.
* **Easy to test delivery in integration tests**. Helpers are provided to make testing a easy and robust.
* **Deliver emails in the background**. Most of the time you don't want or need to wait for the email to send. Bamboo makes it easy with Mailer.deliver_later

See the [docs] for the most up to date information.

[docs]: https://hexdocs.pm/bamboo/readme.html

## Adapters

The official Bamboo adapter is for Mandrill, but there are other adapters as well.

The Bamboo.MandrillAdapter **is being used in production and is known to work**.
Refer to the other adapters README's for their status and for installation
instructions.

* Bamboo.MandrillAdapter | [bamboo]
* Bamboo.SendgridAdapter | [bamboo-sendgrid]

[bamboo]: http://github.com/paulcsmith/bamboo
[bamboo-sendgrid]: https://github.com/mtwilliams/bamboo-sendgrid
[create your own adapter]: https://hexdocs.pm/bamboo/Bamboo.Adapter.html

## Basic Usage

Bamboo breaks email creation and email sending into two separate modules. This
is done to make testing easier and to make emails easy to pipe/compose.

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
    new_email(
      to: "foo@example.com",
      from: "me@example.com",
      subject: "Welcome!!!",
      html_body: "<strong>Welcome</strong>",
      text_body: "welcome"
    )

    # or pipe using Bamboo.Email functions
    new_email
    |> to("foo@example.com")
    |> from("me@example.com")
    |> subject("Welcome!!!")
    |> html_body("<strong>Welcome</strong>")
    |> text_body("welcome")
  end
end

# In a controller or some other module
Emails.welcome_email |> Mailer.deliver_now

# You can also deliver emails in the background with Mailer.deliver_later
Emails.welcome_email |> Mailer.deliver_later
```

## Delivering Emails in the Background

By default delivering later uses `Bamboo.TaskSupervisorStrategy`, but you can
deliver in the background however you want. See [Bamboo.DeliverLaterStrategy].

[Bamboo.DeliverLaterStrategy]: https://hexdocs.pm/bamboo/Bamboo.DeliverLaterStrategy.html

## Composing with Pipes (for default from address, default layouts, etc.)

```elixir
defmodule MyApp.Emails do
  import Bamboo.Email

  def welcome_email do
    base_email
    |> to("foo@bar.com")
    |> subject("Welcome!!!")
    |> put_header("Reply-To", "someone@example.com")
    |> html_body("<strong>Welcome</strong>")
    |> text_body("Welcome")
  end

  defp base_email do
    # Here you can set a default from, default headers, etc.
    new_email
    |> from("myapp@example.com")
    |> put_html_layout({MyApp.LayoutView, "email.html"})
    |> put_text_layout({MyApp.LayoutView, "text.html"})
  end
end
```

## Handling Recipients

The from, to, cc and bcc addresses can be passed a string, a 2 item tuple or
anything that implements the Bamboo.Formatter protocol. See the [Bamboo.Email docs] for more info and examples.

[Bamboo.Email docs]: https://hexdocs.pm/bamboo/Bamboo.Email.html

## Using Phoenix Views and Layouts

You can use Phoenix views and layouts with Bamboo. See [Bamboo.Phoenix]

[Bamboo.Phoenix]: https://hexdocs.pm/bamboo/Bamboo.Phoenix.html

## Mandrill Specific Functionality (tags, merge vars, etc.)

See [Bamboo.MandrillEmail](https://hexdocs.pm/bamboo/Bamboo.MandrillEmail.html)

## Testing

You can use the `Bamboo.TestAdapter` to make testing your emails a piece of cake.
See documentation for [Bamboo.Test] for more examples.

[Bamboo.Test]: https://hexdocs.pm/bamboo/Bamboo.Test.html

## Installation

To use the latest from master.

  1. Add bamboo to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:bamboo, github: "paulcsmith/bamboo"}]
    end
    ```

  2. Ensure bamboo is started before your application:

    ```elixir
    def application do
      [applications: [:bamboo]]
    end
    ```

  3. Add the the Bamboo.TaskSupervior as a child to your supervisor

  ```elixir
  # Usually in lib/my_app_name/my_app_name.ex
  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      # Add the supervisor that handles deliver_later calls
      Bamboo.TaskSupervisorStrategy.child_spec
    ]

    # This part is usually already in the start function
    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
  ```
