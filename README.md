<p align="left"><img src="https://user-images.githubusercontent.com/22394/39895001-b13a9c9a-5476-11e8-9c58-f5fc5f09b697.png" alt="bamboo" height="120px"></p>

# Bamboo [![Circle CI](https://circleci.com/gh/thoughtbot/bamboo/tree/master.svg?style=svg)](https://circleci.com/gh/thoughtbot/bamboo/tree/master) [![Coverage Status](https://coveralls.io/repos/github/thoughtbot/bamboo/badge.png?branch=master)](https://coveralls.io/github/thoughtbot/bamboo?branch=master)

---

**This README follows master, which may not be the currently published version!** Use
[the docs for the published version of Bamboo](https://hexdocs.pm/bamboo/readme.html).

---

**Bamboo is part of the [thoughtbot Elixir family][elixir-phoenix] of projects.**

Flexible and easy to use email for Elixir.

- **Built-in support for popular mail delivery services**. Bamboo ships with
  [adapters for several popular mail delivery services, including Mandrill,
  Mailgun, and SendGrid][available-adapters]. It's also quite easy to write
  your own delivery adapter if your platform isn't yet supported.
- **Deliver emails in the background**. Most of the time you don't want or need
  to wait for the email to send. Bamboo makes it easy with
  `Mailer.deliver_later`.
- **A functional approach to mail delivery**. Emails are created, manipulated,
  and sent using plain functions. This makes composition a breeze and fits
  naturally into your existing Elixir app.
- **Unit test with ease**. Bamboo separates email creation and email delivery
  allowing you to test by asserting against email fields without the need for
  special functions.
- **Dead-simple integration tests**. Bamboo provides helper functions to make
  integration testing easy and robust.
- **View sent emails during development**. Bamboo provides a plug you can use
  in your router to view sent emails.
- **Integrate with Phoenix out of the box**. Use Phoenix views and layouts to
  make rendering email easy.

See the [docs] for the most up to date information.

We designed Bamboo to be simple and powerful. If you run into _anything_ that
is less than exceptional, or you just need some help, please open an issue.

## Installation

To install Bamboo, add it to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [{:bamboo, "~> 1.7.1"}]
end
```

You may also use the latest code available from master instead of a
published version in hex:

```elixir
def deps do
  [{:bamboo, github: "thoughtbot/bamboo"}]
end
```

Once you've added Bamboo to your list, update your dependencies by running:

```sh
$ mix deps.get
```

If you are using Elixir < 1.4, also ensure Bamboo is started alongside your
application:

```elixir
def application do
  [applications: [:bamboo]]
end
```

## Getting Started

Bamboo separates the tasks of email creation and email sending. To use Bamboo,
you'll need to define one or more email modules (email creation), define a
mailer module (email sending), and provide some configuration.

To create emails, define an email module within your application.

```elixir
# some/path/within/your/app/email.ex
defmodule MyApp.Email do
  import Bamboo.Email

  def welcome_email do
    new_email(
      to: "john@example.com",
      from: "support@myapp.com",
      subject: "Welcome to the app.",
      html_body: "<strong>Thanks for joining!</strong>",
      text_body: "Thanks for joining!"
    )
  end
end
```

In addition to the keyword syntax above you can also [compose emails using pipes].

To send emails, define a mailer module for your application that `use`s
Bamboo's mailer.

```elixir
# some/path/within/your/app/mailer.ex
defmodule MyApp.Mailer do
  use Bamboo.Mailer, otp_app: :my_app
end
```

Your configuration will need to know your OTP application, your mailer module,
the adapter you are using, and any additional configuration required by the
adapter itself.

```elixir
# config/config.exs
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key"
```

Bamboo uses [Hackney](https://github.com/benoitc/hackney) for making requests.
If you want to pass options to Hackney directly, such as controlling
timeouts, you can use the `hackney_opts` key:

```elixir
# config/config.exs
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter,
  api_key: "my_api_key",
  hackney_opts: [
    recv_timeout: :timer.minutes(1),
    connect_timeout: :timer.minutes(1)
  ]
```

_Other adapter-specific configuration may be required. Be sure to check the
adapter's docs._

Now that you have configured Bamboo and defined your modules, you can deliver
email in fitting places within your application.

```elixir
defmodule MyApp.SomeControllerPerhaps do
  def send_welcome_email do
    Email.welcome_email()   # Create your email
    |> Mailer.deliver_now() # Send your email
  end
end
```

Your application is now set up to send email with Bamboo! :tada:

## Using Adapters

An adapter is a set of instructions for how to communicate with a specific
email delivery service. Bamboo ships with support for [several popular
services][available-adapters], there are others made available by the
community, or you can use other services by writing a custom adapter.

To use an adapter, declare it in the configuration for your mailer:

```elixir
# config/config.exs
config :my_app, MyApp.Mailer,
  adapter: Bamboo.MandrillAdapter
```

Bamboo provides adapters for use in development and testing. To use these
adapters, declare them in the environment configuration.

The local adapter [stores emails in memory that can be viewed during
development](#viewing-sent-emails). Declare its use in your dev environment.

```elixir
# config/dev.exs
config :my_app, MyApp.Mailer,
  adapter: Bamboo.LocalAdapter
```

The test adapter sends emails to your running process allowing you to test mail
delivery without emails being sent externally. Declare its use in your test
environment.

```elixir
# config/test.exs
config :my_app, MyApp.Mailer,
  adapter: Bamboo.TestAdapter
```

You can create new adapters for any environment by implementing the
[`Bamboo.Adapter`] behaviour.

## Delivering Emails in the Background

Often times you don't want to send an email right away because it can block
process completion (e.g. a web request in Phoenix). Bamboo provides a
`deliver_later` function on your mailers to send emails in the background. It
also provides a [`Bamboo.DeliverLaterStrategy`] behaviour that you can
implement to tailor your background email sending.

By default, `deliver_later`uses [`Bamboo.TaskSupervisorStrategy`]. This strategy
sends the email right away, but it does so in the background without linking to
the calling process, so errors in the mailer won't bring down your app.

You can also create custom strategies by implementing the
[`Bamboo.DeliverLaterStrategy`] behaviour. For example, you could create
strategies for adding emails to a background processing queue such as [exq] or
[toniq].

## Composing with Pipes

In addition to creating emails with keyword lists you, can use pipe syntax to
compose emails. This is particularly useful for providing defaults (e.g. from
address, default layout, etc.)

```elixir
defmodule MyApp.Email do
  import Bamboo.Email
  import Bamboo.Phoenix

  def welcome_email do
    base_email() # Build your default email then customize for welcome
    |> to("foo@bar.com")
    |> subject("Welcome!!!")
    |> put_header("Reply-To", "someone@example.com")
    |> html_body("<strong>Welcome</strong>")
    |> text_body("Welcome")
  end

  defp base_email do
    new_email()
    |> from("myapp@example.com") # Set a default from
    |> put_html_layout({MyApp.LayoutView, "email.html"}) # Set default layout
    |> put_text_layout({MyApp.LayoutView, "email.text"}) # Set default text layout
  end
end
```

## Handling Recipients

The from, to, cc, and bcc addresses can be a string or a 2 element tuple. What
happens if you try to send to a list of `MyApp.User`s? Transforming your data
structure each time you send an email would be a pain.

```elixir
# This stinks. Do you want to do this every time you create a new email?
users = for user <- users do
  {user.name, user.email}
end

new_email(to: users)
```

Bamboo alleviates this pain by providing the [`Bamboo.Formatter`] protocol. By
implementing the protocol for your data structure once, you can pass that
struct directly to Bamboo anywhere it expects an address. See the
[`Bamboo.Email`] and [`Bamboo.Formatter`] docs for more information and
examples.

## Using Phoenix Views and Layouts

Phoenix is not required to use Bamboo. However, if you do use Phoenix, you can
use Phoenix views and layouts with Bamboo. See [`Bamboo.Phoenix`].

## Viewing Sent Emails

Bamboo comes with a handy plug for viewing emails sent in development. Now you
don't have to look at the logs to get password resets, confirmation links, etc.
Just open up the sent email viewer and click the link.

See [`Bamboo.SentEmailViewerPlug`].

Here is what it looks like:

![Screenshot of BambooSentEmailViewer](https://cloud.githubusercontent.com/assets/22394/14929083/bda60b76-0e29-11e6-9e11-5ec60069e825.png)

## Mandrill Specific Functionality (tags, merge vars, templates, etc.)

Mandrill offers extra features on top of regular SMTP email like tagging, merge
vars, templates, and scheduling emails to send in the future. See
[`Bamboo.MandrillHelper`].

## SendGrid Specific Functionality (templates, substitution tags, scheduled delivery, etc.)

SendGrid offers extra features on top of regular SMTP email like transactional
templates with substitution tags. See [`Bamboo.SendGridHelper`].

## JSON support

Bamboo comes with JSON support out of the box via the [Jason] library. To use
it, add `:jason` to your dependencies:

```elixir
{:jason, "~> 1.0"}
```

You can customize it to use another library via the `:json_library`
configuration:

```elixir
config :bamboo, :json_library, SomeOtherLib
```

## Testing

Bamboo separates email creation and email sending. Test email creation by
asserting against the email struct created by your functions. For example,
assuming your welcome email accepts a user recipient, provides the correct from
address, and provides specific text, you might test like this:

```elixir
defmodule MyApp.EmailTest do
  use ExUnit.Case

  test "welcome email" do
    user = {"Ralph", "ralph@example.com"}

    email = MyApp.Email.welcome_email(user)

    assert email.to == user
    assert email.from == "welcome@myapp.com"
    assert email.html_body =~ "<p>Thanks for joining</p>"
    assert email.text_body =~ "Thanks for joining"
  end
end
```

Test email sending in integration tests by using the [`Bamboo.TestAdapter`]
along with [`Bamboo.Test`]. For example, assuming during the registration
process of your app an email is sent to the user welcoming them to the
application, you might test this feature like this:

```elixir
defmodule MyApp.RegistrationTest do
  use ExUnit.Case
  use Bamboo.Test

  # Remember to use the `Bamboo.TestAdapter` in your test config

  test "after registering, the user gets a welcome email" do
    user = new_user()
    expected_email = MyApp.Email.welcome_email(user.email)

    MyApp.Registration.create(user)

    assert_delivered_email expected_email
  end

  defp new_user do
    # Build a user appropriate to your application
  end
end
```

See the documentation for [`Bamboo.Test`] for more examples and additional
helper functions.

## Available Adapters

Here is a list of adapters that either ship with Bamboo or have been made
available by the community. Feel free to open an issue or a PR if you'd like to
add a new adapter to the list.

- `Bamboo.LocalAdapter` - Ships with Bamboo. Stores email in memory. Great for local development.
- `Bamboo.MailgunAdapter` - Ships with Bamboo. Thanks to [@princemaple].
- `Bamboo.MandrillAdapter` - Ships with Bamboo.
- `Bamboo.SendGridAdapter` - Ships with Bamboo.
- `Bamboo.TestAdapter` - Ships with Bamboo. Use in your test environment.
- `Bamboo.CampaignMonitorAdapter` - See [jackmarchant/bamboo_campaign_monitor](https://github.com/jackmarchant/bamboo_campaign_monitor).
- `Bamboo.ConfigAdapter` - See [BinaryNoggin/bamboo_config_adapter](https://github.com/BinaryNoggin/bamboo_config_adapter) declare config at runtime.
- `Bamboo.FallbackAdapter` - See [fuelen/bamboo_fallback](https://github.com/fuelen/bamboo_fallback). Allows using multiple adapters.
- `Bamboo.GmailAdapter` - See [parkerduckworth/bamboo_gmail](https://github.com/parkerduckworth/bamboo_gmail).
- `Bamboo.MailjetAdapter` - See [moxide/bamboo_mailjet](https://github.com/moxide/bamboo_mailjet).
- `Bamboo.PostmarkAdapter` - See [pablo-co/bamboo_postmark](https://github.com/pablo-co/bamboo_postmark).
- `Bamboo.SendcloudAdapter` - See [linjunpop/bamboo_sendcloud](https://github.com/linjunpop/bamboo_sendcloud).
- `Bamboo.SesAdapter` - See [kalys/bamboo_ses](https://github.com/kalys/bamboo_ses).
- `Bamboo.SMTPAdapter` - See [fewlinesco/bamboo_smtp](https://github.com/fewlinesco/bamboo_smtp).
- `Bamboo.SparkPostAdapter` - See [andrewtimberlake/bamboo_sparkpost](https://github.com/andrewtimberlake/bamboo_sparkpost).

## Contributing

Before opening a pull request, please open an issue first.

Once we've decided how to move forward with a pull request:

    $ git clone https://github.com/thoughtbot/bamboo.git
    $ cd bamboo
    $ mix deps.get
    $ mix test
    $ mix format

Once you've made your additions and `mix test` passes, go ahead and open a PR!

We run the test suite as well as formatter checks on CI. Make sure you are using
the Elixir version defined in the `.tool-versions` file to have consistent
formatting with what's being run on CI.

## About thoughtbot

![thoughtbot](http://presskit.thoughtbot.com/images/thoughtbot-logo-for-readmes.svg)

Bamboo is maintained and funded by thoughtbot, inc.
The names and logos for thoughtbot are trademarks of thoughtbot, inc.

We love open-source software, Elixir, and Phoenix. See [our other Elixir
projects][elixir-phoenix], or [hire our Elixir Phoenix development team][hire]
to design, develop, and grow your product.

[elixir-phoenix]: https://thoughtbot.com/services/elixir-phoenix?utm_source=github
[hire]: https://thoughtbot.com?utm_source=github

## Thanks!

Thanks to @mtwilliams for an early version of the `SendGridAdapter`.

<!-- Links -->

[@princemaple]: https://github.com/princemaple
[`bamboo.adapter`]: https://hexdocs.pm/bamboo/Bamboo.Adapter.html
[`bamboo.deliverlaterstrategy`]: https://hexdocs.pm/bamboo/Bamboo.DeliverLaterStrategy.html
[`bamboo.email`]: https://hexdocs.pm/bamboo/Bamboo.Email.html
[`bamboo.formatter`]: https://hexdocs.pm/bamboo/Bamboo.Formatter.html
[`bamboo.mandrillhelper`]: https://hexdocs.pm/bamboo/Bamboo.MandrillHelper.html
[`bamboo.phoenix`]: https://hexdocs.pm/bamboo/Bamboo.Phoenix.html
[`bamboo.sendgridhelper`]: https://hexdocs.pm/bamboo/Bamboo.SendGridHelper.html
[`bamboo.sentemailviewerplug`]: https://hexdocs.pm/bamboo/Bamboo.SentEmailViewerPlug.html
[`bamboo.tasksupervisorstrategy`]: https://hexdocs.pm/bamboo/Bamboo.TaskSupervisorStrategy.html
[`bamboo.test`]: https://hexdocs.pm/bamboo/Bamboo.Test.html
[`bamboo.testadapter`]: https://hexdocs.pm/bamboo/Bamboo.TestAdapter.html
[`bamboo`]: http://github.com/thoughtbot/bamboo
[available-adapters]: #available-adapters
[compose emails using pipes]: #composing-with-pipes
[create your own adapter]: https://hexdocs.pm/bamboo/Bamboo.Adapter.html
[docs]: https://hexdocs.pm/bamboo/readme.html
[exq]: https://github.com/akira/exq
[free bamboo screencast from dailydrip]: https://www.dailydrip.com/topics/elixir/drips/bamboo-email
[jason]: https://github.com/michalmuskala/jason
[toniq]: https://github.com/joakimk/toniq
