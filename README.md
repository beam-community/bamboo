

Bamboo [![Circle CI](https://circleci.com/gh/paulcsmith/bamboo/tree/master.svg?style=svg)](https://circleci.com/gh/paulcsmith/bamboo/tree/master) [![Coverage Status](https://coveralls.io/repos/github/paulcsmith/bamboo/badge.png?branch=master)](https://coveralls.io/github/paulcsmith/bamboo?branch=master)
========

Flexible and easy to use email for Elixir.

* **Adapter based** so it can be used with Mandrill, SMTP, or whatever else you want. Comes with a Mandrill adapter out of the box.
* **Deliver emails in the background**. Most of the time you don't want or need to wait for the email to send. Bamboo makes it easy with Mailer.deliver_later
* **Easy to format recipients**. You can do `new_email(to: Repo.one(User))` and Bamboo can format the User struct if you implement Bamboo.Formatter.
* **Works out of the box with Phoenix**. Use views and layouts to make rendering email easy.
* **Very composable**. Emails are just a Bamboo.Email struct and be manipulated with plain functions.
* **Easy to unit test**. Because delivery is separated from email creation, no special functions are needed, just assert against fields on the email.
* **Easy to test delivery in integration tests**. Helpers are provided to make testing a easy and robust.
* **Preview sent emails during development**. Bamboo comes with a plug that can be used in your router to preview sent emails.

See the [docs] for the most up to date information.

We designed Bamboo to be simple and powerful. If you run into *anything* that is
less than exceptional, or you just need some help, please open an issue.

[docs]: https://hexdocs.pm/bamboo/readme.html

## Adapters

The official Bamboo adapter is for Mandrill, but there are other adapters as well.

The Bamboo.MandrillAdapter **is being used in production** and has had no issues.
Refer to other adapters README's for their status and for installation
instructions. It's also pretty simple to [create your own adapter].

* `Bamboo.MandrillAdapter` - Ships with Bamboo.
* `Bamboo.LocalAdapter` - Ships with Bamboo. Stores email in memory. Great for local development.
* `Bamboo.TestAdapter` - Ships with Bamboo. Use in your test environment.
* `Bamboo.SendgridAdapter` - Check out [bamboo-sendgrid] by @mtwilliams.

To switch adapters, change the config for your mailer

```elixir
# In your config file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.LocalAdapter
```

[bamboo]: http://github.com/paulcsmith/bamboo
[bamboo-sendgrid]: https://github.com/mtwilliams/bamboo-sendgrid
[create your own adapter]: https://hexdocs.pm/bamboo/Bamboo.Adapter.html

## Getting Started

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
defmodule MyApp.Email do
  import Bamboo.Email

  def welcome_email do
    new_email(
      to: "john@gmail.com",
      from: "support@myapp.com",
      subject: "Welcome to the app.",
      html_body: "<strong>Thanks for joining!</strong>",
      text_body: "Thanks for joining!"
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
Email.welcome_email |> Mailer.deliver_now

# You can also deliver emails in the background with Mailer.deliver_later
Email.welcome_email |> Mailer.deliver_later
```

## Delivering Emails in the Background

Often times you don't want to send email right away because it will slow down things like web requests in Phoenix.
Bamboo offers `deliver_later` on your mailers to send emails in the background so that your requests don't block.

By default delivering later uses [`Bamboo.TaskSupervisorStrategy`](https://hexdocs.pm/bamboo/Bamboo.TaskSupervisorStrategy.html). This strategy sends the email right away, but does so in the background without linking to the calling process, so errors in the mailer won't bring down your app.

If you need something more custom you can
can create a strategy with [Bamboo.DeliverLaterStrategy](https://hex.pm/packages/bamboo). For example, you could create strategies
for adding emails to a background processing queue such as [exq](https://github.com/akira/exq/tree/master/test) or [toniq](https://github.com/joakimk/toniq).

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

The from, to, cc and bcc addresses can be passed a string, or a 2 item tuple.

Sometimes doing this can be a pain though. What happens if you try to send to a list of users? You'd have to do something like this for every email:

```elixir
# Where users looks like [%User{name: "John", email: "john@gmail.com"}]
users = for user <- users do
  {user.name, user.email}
end

new_email(to: users)
```

To help with this, Bamboo has a `Bamboo.Formatter` protocol.
See the [Bamboo.Email] and [Bamboo.Formatter docs] for more info and examples.

[Bamboo.Email]: https://hexdocs.pm/bamboo/Bamboo.Email.html
[Bamboo.Formatter docs]: https://hexdocs.pm/bamboo/Bamboo.Formatter.html

## Using Phoenix Views and Layouts

Phoenix is not required to use Bamboo. However, if you do use Phoenix, you can use Phoenix views and layouts with Bamboo. See [Bamboo.Phoenix](https://hexdocs.pm/bamboo/Bamboo.Phoenix.html)

## Previewing Sent Emails

Bamboo comes with a handy plug for viewing emails sent in development. Now you
don't have to look at the logs to get password resets, confirmation links, etc.
Just open up the email preview and click the link.

See [Bamboo.EmailPreviewPlug](https://hexdocs.pm/bamboo/Bamboo.EmailPreviewPlug.html)

## Mandrill Specific Functionality (tags, merge vars, etc.)

Mandrill offers extra features on top of regular SMTP email like tagging, merge vars, and scheduling emails to send in the future. See [Bamboo.MandrillHelper](https://hexdocs.pm/bamboo/Bamboo.MandrillHelper.html).

## Testing

You can use the Bamboo.TestAdapter along with [Bamboo.Test] to make testing your emails a piece of cake.

```elixir
# Using the mailer from the Getting Started section
defmodule MyApp.Registration do
  use ExUnit.Case
  use Bamboo.Test

  test "welcome email" do
    # Unit testing is easy since the email is just a struct
    user = new_user

    email = Emails.welcome_email(user)

    assert email.to == user
    # The =~ checks that the html_body contains the text on the right
    assert email.html_body =~ "Thanks for joining"
  end

  test "after registering, the user gets a welcome email" do
    # Integration test with the helpers from Bamboo.Test
    user = new_user

    MyApp.Register(user)

    assert_delivered_email MyApp.Email.welcome_email(user)
  end
end
```

See documentation for [Bamboo.Test] for more examples, and remember to use
Bamboo.TestAdapter.

[Bamboo.Test]: https://hexdocs.pm/bamboo/Bamboo.Test.html

## Installation

1. Add bamboo to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    # Get from hex
    [{:bamboo, "~> 0.4"}]
    # Or use the latest from master
    [{:bamboo, github: "paulcsmith/bamboo"}]
  end
  ```

2. Ensure bamboo is started before your application:

  ```elixir
  def application do
    [applications: [:bamboo]]
  end
  ```

3. Add the the `Bamboo.TaskSupervisor` as a child to your supervisor. This is necessary for `deliver_later` to work.

  ```elixir
  # Usually in lib/my_app_name.ex
  children = [
    # This is where you add the supervisor that handles deliver_later calls
    Bamboo.TaskSupervisorStrategy.child_spec
  ]
  ```

## Contributing

Before opening a pull request, please open an issue first.

    $ git clone https://github.com/paulcsmith/bamboo.git
    $ cd ex_machina
    $ mix deps.get
    $ mix test

Once you've made your additions and `mix test` passes, go ahead and open a PR!
