Upgrading to Bamboo 2.0
=======================

Bamboo 2.0 ships with some breaking changes (hence the major version bump). But
don't worry, if you love Bamboo just as it is, there's an easy upgrade path.

There are two breaking changes:

- `Bamboo.Phoenix` extracted to [bamboo_phoenix]
- `Bamboo.Mailer.deliver_now/2` and `deliver_later/2` don't raise on errors

Let's cover each in turn.

## Breaking change: `Bamboo.Phoenix` extracted to `bamboo_phoenix`

`Bamboo.Phoenix` has been extracted to the [bamboo_phoenix] library. If you use
`Bamboo.Phoenix` to render your email templates, add `bamboo_phoenix` to your
dependencies:

```elixir
defp deps do
  [
    ...
    {:bamboo, "~> 2.0"},
    {:bamboo_phoenix, "~> 1.0"}
    ...
  ]
end
```

## Breaking change: `deliver_now/2`/`deliver_later/2` return `:ok` & `:error` tuples

`Bamboo.Mailer`'s `deliver_now/2` and `deliver_later/2` no longer raise errors.
Instead, they now return an `{:ok, email}` and `{:error, error}`, where the
`error` is an exception struct or an error message. If you pass `response:
true` as an argument, the return value will be `{:ok, email, response}`.

If you prefer seeing code, this is the change in `@spec` signature for
`deliver_now/2`:

```diff
-  @spec deliver_now(Bamboo.Email.t(), Enum.t()) :: Bamboo.Email.t() | {Bamboo.Email.t(), any}
+  @spec deliver_now(Bamboo.Email.t(), Enum.t()) ::
+          {:ok, Bamboo.Email.t()}
+          | {:ok, Bamboo.Email.t(), any}
+          | {:error, Exception.t() | String.t()}
```

Note that `deliver_later/2` will only return errors that happen _prior_ to
scheduling the delivery of the email. What happens once the delivery is
scheduled depends on what [delivery strategy] you are using.

Those who want to handle errors on their own can now pattern match on the `:ok`
and `:error` tuple responses. If you don't want to handle the errors and like
how Bamboo behaves prior to 2.0, there's a simple upgrade path. 👇

### Simple upgrade path

`Bamboo.Mailer` comes with `deliver_now/2!` and `deliver_later/2!`. Those two
functions mirror the behavior that `deliver_now/2` and `deliver_later/2` had
before 2.0.

Hopefully, that makes for a simple upgrade path for those who don't want to
handle the `{:ok, email}` and `{:error, error}` tuples. You only need to
change:

- `deliver_now/2` to `deliver_now/2!`, and
- `deliver_later/2` to `deliver_later/2!`

Note that `deliver_later/2!` will only raise email validation errors _before_
scheduling the email delivery. What happens after the delivery is scheduled
depends on the [delivery strategy] you are using (e.g.
`TaskSupervisorStrategy`).

### `TaskSupervisorStrategy`

Regardless of whether you use `deliver_later/2` or `deliver_later/2!`, if you
use the `TaskSupervisorStrategy` for delivering emails, it will continue to
raise errors when emails fail to be delivered.

If you want control of those errors, you can implement a custom [delivery
strategy], to handle errors coming from `adapter.deliver`.

For now, `TaskSupervisorStrategy` continues to work as it did prior to `2.0`,
so no change is needed here to upgrade to Bamboo 2.0.

### Check with your adapter

Each adapter needs to upgrade to satisfy the new [adapter.deliver callback].
Check with your adapter to see if it supports the new `ok` and `error` tuple
API before upgrading to Bamboo 2.0.

If you use SendGrid, Mailgun, or Mandrill, your adapter is already updated with
Bamboo 2.0.

That's it! For a full list of changes, please refer to the [changelog].

And if you find any issues with this upgrade guide, please let us know by
[opening an issue] or submitting a pull-request.

[adapter.deliver callback]: https://hexdocs.pm/bamboo/2.0.0/Bamboo.Adapter.html#c:deliver/2
[delivery strategy]: https://hexdocs.pm/bamboo/2.0.0/Bamboo.DeliverLaterStrategy.html
[opening an issue]: https://github.com/thoughtbot/bamboo/issues
[bamboo_phoenix]: https://hexdocs.pm/bamboo_phoenix
[changelog]: https://github.com/thoughtbot/bamboo/blob/master/CHANGELOG.md
