<p align="left"><img src="https://user-images.githubusercontent.com/22394/39895001-b13a9c9a-5476-11e8-9c58-f5fc5f09b697.png" alt="bamboo" height="120px"></p>

Bamboo [![Circle CI](https://circleci.com/gh/thoughtbot/bamboo/tree/master.svg?style=svg)](https://circleci.com/gh/thoughtbot/bamboo/tree/master) [![Coverage Status](https://coveralls.io/repos/github/thoughtbot/bamboo/badge.png?branch=master)](https://coveralls.io/github/thoughtbot/bamboo?branch=master)
========

> **This README follows master, which may not be the currently published version!** Use
[the docs for the published version of Bamboo](https://hexdocs.pm/bamboo/readme.html).

**Bamboo is part of the [thoughtbot Elixir family][elixir-phoenix] of projects.**

Flexible and easy to use email for Elixir.

* **Adapter based** so it can be used with Mandrill, SMTP, or whatever else you want. Comes with a Mandrill adapter out of the box.
* **Deliver emails in the background**. Most of the time you don't want or need to wait for the email to send. Bamboo makes it easy with Mailer.deliver_later
* **Easy to format recipients**. You can do `new_email(to: Repo.one(User))` and Bamboo can format the User struct if you implement Bamboo.Formatter.
* **Works out of the box with Phoenix**. Use views and layouts to make rendering email easy.
* **Very composable**. Emails are just a Bamboo.Email struct and can be manipulated with plain functions.
* **Easy to unit test**. Because delivery is separated from email creation, no special functions are needed, just assert against fields on the email.
* **Easy to test delivery in integration tests**. Helpers are provided to make testing easy and robust.
* **View sent emails during development**. Bamboo comes with a plug that can be used in your router to view sent emails.

See the [docs] for the most up to date information.

We designed Bamboo to be simple and powerful. If you run into *anything* that is
less than exceptional, or you just need some help, please open an issue.

[docs]: https://hexdocs.pm/bamboo/readme.html

## Adapters

The Bamboo.MandrillAdapter and Bamboo.SendGridAdapter **are being used in production**
and have had no issues. It's also pretty simple to [create your own adapter]. Feel free
to open an issue or a PR if you'd like to add a new adapter to the list.


* `Bamboo.ConfigAdapter` - See [BinaryNoggin/bamboo_config_adapter](https://github.com/BinaryNoggin/bamboo_config_adapter) declare config at runtime.
* `Bamboo.MailgunAdapter` - Ships with Bamboo. Thanks to [@princemaple].
* `Bamboo.MailjetAdapter` - See [moxide/bamboo_mailjet](https://github.com/moxide/bamboo_mailjet).
* `Bamboo.MandrillAdapter` - Ships with Bamboo.
* `Bamboo.SendGridAdapter` - Ships with Bamboo.
* `Bamboo.SMTPAdapter` - See [fewlinesco/bamboo_smtp](https://github.com/fewlinesco/bamboo_smtp).
* `Bamboo.SparkPostAdapter` - See [andrewtimberlake/bamboo_sparkpost](https://github.com/andrewtimberlake/bamboo_sparkpost).
* `Bamboo.PostmarkAdapter` - See [pablo-co/bamboo_postmark](https://github.com/pablo-co/bamboo_postmark).
* `Bamboo.SendcloudAdapter` - See [linjunpop/bamboo_sendcloud](https://github.com/linjunpop/bamboo_sendcloud).
* `Bamboo.LocalAdapter` - Ships with Bamboo. Stores email in memory. Great for local development.
* `Bamboo.TestAdapter` - Ships with Bamboo. Use in your test environment.

[@princemaple]: https://github.com/princemaple

To switch adapters, change the config for your mailer:

```elixir
# In your config file
config :my_app, MyApp.Mailer,
  adapter: Bamboo.LocalAdapter
```

[bamboo]: http://github.com/thoughtbot/bamboo
[create your own adapter]: https://hexdocs.pm/bamboo/Bamboo.Adapter.html

## Installation

1. Add bamboo to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    # Get from hex
    [{:bamboo, "~> 0.8"}]
    # Or use the latest from master
    [{:bamboo, github: "thoughtbot/bamboo"}]
  end
  ```

2. Ensure bamboo is started before your application:

  ```elixir
  def application do
    [applications: [:bamboo]]
  end
  ```

## Getting Started

> **Do you like to learn by watching?** Check out the [free Bamboo screencast from DailyDrip].

> It is a wonderful introduction to sending and testing emails with Bamboo. It also covers some of the ways that Bamboo helps catch errors, how some of the internals work, and how to format recipients with the Bamboo.Formatter protocol.

[free Bamboo screencast from DailyDrip]: https://www.dailydrip.com/topics/elixir/drips/bamboo-email

Bamboo breaks email creation and email sending into two separate modules. This
is done to make testing easier and to make emails easy to pipe/compose.

```elixir
# In your config/config.exs file
#
# There may be other adapter specific configuration you need to add.
# Be sure to check the adapter's docs. For example, Mailgun requires a `domain` key.
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
create a strategy with [`Bamboo.DeliverLaterStrategy`](https://hexdocs.pm/bamboo/Bamboo.DeliverLaterStrategy.html). For example, you could create strategies
for adding emails to a background processing queue such as [exq](https://github.com/akira/exq) or [toniq](https://github.com/joakimk/toniq).

## Composing with Pipes (for default from address, default layouts, etc.)

```elixir
defmodule MyApp.Email do
  import Bamboo.Email
  import Bamboo.Phoenix

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
    |> put_text_layout({MyApp.LayoutView, "email.text"})
  end
end
```

## Handling Recipients

The from, to, cc and bcc addresses can be passed a string, or a 2 item tuple.

Sometimes doing this can be a pain though. What happens if you try to send to a list of users? You'd have to do something like this for every email:

```elixir
# This stinks. Do you want to do this every time you create a new email?
users = for user <- users do
  {user.name, user.email}
end

new_email(to: users)
```

To circumvent this, Bamboo has a `Bamboo.Formatter` protocol.
See the [Bamboo.Email] and [Bamboo.Formatter docs] for more info and examples.

[Bamboo.Email]: https://hexdocs.pm/bamboo/Bamboo.Email.html
[Bamboo.Formatter docs]: https://hexdocs.pm/bamboo/Bamboo.Formatter.html

## Using Phoenix Views and Layouts

Phoenix is not required to use Bamboo. However, if you do use Phoenix, you can
use Phoenix views and layouts with Bamboo. See
[Bamboo.Phoenix](https://hexdocs.pm/bamboo/Bamboo.Phoenix.html)

## Viewing Sent Emails

Bamboo comes with a handy plug for viewing emails sent in development. Now you
don't have to look at the logs to get password resets, confirmation links, etc.
Just open up the sent email viewer and click the link.

See [Bamboo.SentEmailViewerPlug](https://hexdocs.pm/bamboo/Bamboo.SentEmailViewerPlug.html)

Here is what it looks like:

![Screenshot of BambooSentEmailViewer](https://cloud.githubusercontent.com/assets/22394/14929083/bda60b76-0e29-11e6-9e11-5ec60069e825.png)

## Mandrill Specific Functionality (tags, merge vars, templates, etc.)

Mandrill offers extra features on top of regular SMTP email like tagging, merge
vars, templates, and scheduling emails to send in the future. See
[Bamboo.MandrillHelper](https://hexdocs.pm/bamboo/Bamboo.MandrillHelper.html).

## SendGrid Specific Functionality (templates and substitution tags)

SendGrid offers extra features on top of regular SMTP email like transactional
templates with substitution tags. See
[Bamboo.SendGridHelper](https://hexdocs.pm/bamboo/Bamboo.SendGridHelper.html).

## Testing

You can use the Bamboo.TestAdapter along with [Bamboo.Test] to make testing your
emails straightforward.

```elixir
# Using the mailer from the Getting Started section
defmodule MyApp.Registration do
  use ExUnit.Case
  use Bamboo.Test

  test "welcome email" do
    # Unit testing is easy since the email is just a struct
    user = new_user

    email = Email.welcome_email(user)

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

## About thoughtbot

![thoughtbot](http://presskit.thoughtbot.com/images/thoughtbot-logo-for-readmes.svg)

Bamboo is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open source software, Elixir, and Phoenix. See [our other Elixir
projects][elixir-phoenix], or [hire our Elixir Phoenix development team][hire]
to design, develop, and grow your product.

[elixir-phoenix]: https://thoughtbot.com/services/elixir-phoenix?utm_source=github
[hire]: https://thoughtbot.com?utm_source=github

## Contributing

Before opening a pull request, please open an issue first.

Once we've decided how to move forward with a pull request:

    $ git clone https://github.com/thoughtbot/bamboo.git
    $ cd bamboo
    $ mix deps.get
    $ mix test

Once you've made your additions and `mix test` passes, go ahead and open a PR!

## Thanks!

Thanks to @mtwilliams for an early version of the `SendGridAdapter`.
