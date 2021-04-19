defmodule Bamboo.Mailer do
  @moduledoc """
  Functions for delivering emails using adapters and delivery strategies.

  Adds `deliver_now/1`, `deliver_now!/1`, `deliver_later/1` and
  `deliver_later!/1` functions to the mailer module in which it is used.

  Bamboo [ships with several adapters][available-adapters]. It is also possible
  to create your own adapter.

  See the ["Getting Started" section of the README][getting-started] for an
  example of how to set up and configure a mailer for use.

  [available-adapters]: https://github.com/thoughtbot/bamboo/tree/master/lib/bamboo/adapters
  [getting-started]: https://hexdocs.pm/bamboo/readme.html#getting-started

  ## Example

  Creating a Mailer is as simple as defining a module in your application and
  using the `Bamboo.Mailer`.

      # some/path/within/your/app/mailer.ex
      defmodule MyApp.Mailer do
        use Bamboo.Mailer, otp_app: :my_app
      end

  The mailer requires some configuration within your application.

      # config/config.exs
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.MandrillAdapter, # Specify your preferred adapter
        api_key: "my_api_key" # Specify adapter-specific configuration

  Also you will want to define an email module for building email structs that
  your mailer can send. See [`Bamboo.Email`] for more information.

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

  You are now able to send emails with your mailer module where you see fit
  within your application.
  """

  @cannot_call_directly_error """
  cannot call Bamboo.Mailer directly. Instead implement your own Mailer module
  with: use Bamboo.Mailer, otp_app: :my_app
  """

  require Logger
  alias Bamboo.Formatter

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @spec deliver_now(Bamboo.Email.t(), Enum.t()) ::
              {:ok, Bamboo.Email.t()}
              | {:ok, Bamboo.Email.t(), any}
              | {:error, Exception.t() | String.t()}

      def deliver_now(email, opts \\ []) do
        {config, opts} = Keyword.split(opts, [:config])
        config = build_config(config)
        Bamboo.Mailer.deliver_now(config.adapter, email, config, opts)
      end

      @spec deliver_now!(Bamboo.Email.t(), Enum.t()) :: Bamboo.Email.t() | {Bamboo.Email.t(), any}
      def deliver_now!(email, opts \\ []) do
        {config, opts} = Keyword.split(opts, [:config])
        config = build_config(config)
        Bamboo.Mailer.deliver_now!(config.adapter, email, config, opts)
      end

      @spec deliver_later(Bamboo.Email.t()) ::
              {:ok, Bamboo.Email.t()} | {:error, Exception.t() | String.t()}
      def deliver_later(email, opts \\ []) do
        config = build_config(opts)
        Bamboo.Mailer.deliver_later(config.adapter, email, config)
      end

      @spec deliver_later!(Bamboo.Email.t()) :: Bamboo.Email.t()
      def deliver_later!(email, opts \\ []) do
        config = build_config(opts)
        Bamboo.Mailer.deliver_later!(config.adapter, email, config)
      end

      otp_app = Keyword.fetch!(opts, :otp_app)

      defp build_config(config: dynamic_config_overrides) do
        Bamboo.Mailer.build_config(
          __MODULE__,
          unquote(otp_app),
          dynamic_config_overrides
        )
      end

      defp build_config(_) do
        Bamboo.Mailer.build_config(__MODULE__, unquote(otp_app))
      end

      @spec deliver(any()) :: no_return()
      def deliver(_email) do
        raise """
        you called deliver/1, but it has been renamed to deliver_now/1 to add clarity.

        Use deliver_now/1 to send right away, or deliver_later/1 to send in the background.
        """
      end
    end
  end

  @doc """
  Deliver an email right away.

  Call your mailer with `deliver_now/1` to send an email right away. Call
  `deliver_later/1` if you want to send in the background.

  Pass in an argument of `response: true` if you need access to the response
  from delivering the email.

  A successful email delivery returns an ok tuple with the `Email` struct and
  the response (if `response: true`) from calling `deliver` with your adapter.

  A failure returns `{:error, error}` tuple.

  Having the response returned from your adapter is useful if you need access to
  any data sent back from your email provider in the response.

      {:ok, email, response} = Email.welcome_email |> Mailer.deliver_now(response: true)

  Pass in an argument of `config: %{}` if you would like to dynamically override
  any keys in your application's default Mailer configuration.

      Email.welcome_email
      |> Mailer.deliver_now(config: %{username: "Emma", smtp_port: 2525})
  """
  def deliver_now(_email, _opts \\ []) do
    raise @cannot_call_directly_error
  end

  @doc """
  Deliver an email right away.

  Same as `deliver_now/2` but does not return an ok/error tuple.

  If successful, this function returns the `Email` struct or an `Email`,
  response tuple when setting `response: true`.

  On failure, this function returns an error tuple: `{:error, error}`.
  """
  def deliver_now!(_email, _opts \\ []) do
    raise @cannot_call_directly_error
  end

  @doc """
  Deliver an email in the background.

  Call your mailer with `deliver_later/1` to send an email using the configured
  `deliver_later_strategy`. If no `deliver_later_strategy` is set,
  `Bamboo.TaskSupervisorStrategy` will be used. See
  `Bamboo.DeliverLaterStrategy` to learn how to change how emails are delivered
  with `deliver_later/1`.

  If the email is successfully scheduled for delivery, this function will return
  an `{:ok, email}`.

  If the email is invalid, this function will return an `{:error, error}` tuple.
  """
  def deliver_later(_email, _opts \\ []) do
    raise @cannot_call_directly_error
  end

  @doc """
  Deliver an email in the background.

  Same as `deliver_later/2` but does not return an ok tuple and raises on
  errors.

  If successful, this function only returns the `Email` struct.

  If the email is invalid, this function raises an error.
  """
  def deliver_later!(_email, _opts \\ []) do
    raise @cannot_call_directly_error
  end

  @doc false
  def deliver_now(adapter, email, config, opts) do
    with {:ok, email} <- validate_and_normalize(email, adapter),
         %Bamboo.Email{blocked: false} = email <- apply_interceptors(email, config) do
      if empty_recipients?(email) do
        debug_unsent(email)

        {:ok, email}
      else
        debug_sent(email, adapter)

        case adapter.deliver(email, config) do
          {:ok, response} -> format_response(email, response, opts)
          {:error, _} = error -> error
        end
      end
    else
      %Bamboo.Email{blocked: true} = email -> {:ok, email}
      response -> response
    end
  end

  defp format_response(email, response, opts) do
    put_response = Keyword.get(opts, :response, false)

    if put_response do
      {:ok, email, response}
    else
      {:ok, email}
    end
  end

  @doc false
  def deliver_now!(adapter, email, config, opts) do
    case deliver_now(adapter, email, config, opts) do
      {:ok, email, response} -> {email, response}
      {:ok, email} -> email
      {:error, error} -> raise error
    end
  end

  @doc false
  def deliver_later(adapter, email, config) do
    with {:ok, email} <- validate_and_normalize(email, adapter),
         %Bamboo.Email{blocked: false} = email <- apply_interceptors(email, config) do
      if empty_recipients?(email) do
        debug_unsent(email)
      else
        debug_sent(email, adapter)
        config.deliver_later_strategy.deliver_later(adapter, email, config)
      end

      {:ok, email}
    else
      %Bamboo.Email{blocked: true} = email -> {:ok, email}
      response -> response
    end
  end

  @doc false
  def deliver_later!(adapter, email, config) do
    case deliver_later(adapter, email, config) do
      {:ok, email} -> email
      {:error, error} -> raise error
    end
  end

  defp empty_recipients?(email) do
    email.to == [] && email.cc == [] && email.bcc == []
  end

  defp debug_sent(email, adapter) do
    Logger.debug(fn ->
      """
      Sending email with #{inspect(adapter)}:

      #{inspect(email, limit: 150)}
      """
    end)
  end

  defp debug_unsent(email) do
    Logger.debug(fn ->
      """
      Email was not sent because recipients are empty.

      Full email - #{inspect(email, limit: 150)}
      """
    end)
  end

  defp validate_and_normalize(email, adapter) do
    case validate(email, adapter) do
      :ok -> {:ok, normalize_addresses(email)}
      error -> error
    end
  end

  defp validate(email, adapter) do
    with :ok <- validate_from_address(email),
         :ok <- validate_recipients(email),
         :ok <- validate_attachment_support(email, adapter) do
      :ok
    end
  end

  defp validate_attachment_support(%{attachments: []} = _email, _adapter), do: :ok

  defp validate_attachment_support(_email, adapter) do
    if Code.ensure_loaded?(adapter) && function_exported?(adapter, :supports_attachments?, 0) &&
         adapter.supports_attachments? do
      :ok
    else
      {:error, "the #{adapter} does not support attachments yet."}
    end
  end

  defp validate_from_address(%{from: nil}) do
    {:error, %Bamboo.EmptyFromAddressError{}}
  end

  defp validate_from_address(%{from: {_, nil}}) do
    {:error, %Bamboo.EmptyFromAddressError{}}
  end

  defp validate_from_address(_email), do: :ok

  defp validate_recipients(%Bamboo.Email{} = email) do
    if Enum.all?(
         Enum.map([:to, :cc, :bcc], &Map.get(email, &1)),
         &is_nil_recipient?/1
       ) do
      {:error, Bamboo.NilRecipientsError.exception(email)}
    else
      :ok
    end
  end

  defp is_nil_recipient?(nil), do: true
  defp is_nil_recipient?({_, nil}), do: true
  defp is_nil_recipient?([]), do: false

  defp is_nil_recipient?([_ | _] = recipients) do
    Enum.all?(recipients, &is_nil_recipient?/1)
  end

  defp is_nil_recipient?(_), do: false

  defp apply_interceptors(email, config) do
    interceptors = config[:interceptors] || []

    Enum.reduce(interceptors, email, fn interceptor, email ->
      apply(interceptor, :call, [email])
    end)
  end

  @doc """
  Wraps to, cc and bcc addresses in a list and normalizes email addresses.

  Also formats the from address. Email normalization/formatting is done by
  implementations of the [Bamboo.Formatter] protocol.
  """
  def normalize_addresses(email) do
    %{
      email
      | from: format(email.from, :from),
        to: format(List.wrap(email.to), :to),
        cc: format(List.wrap(email.cc), :cc),
        bcc: format(List.wrap(email.bcc), :bcc)
    }
  end

  defp format(record, type) do
    Formatter.format_email_address(record, %{type: type})
  end

  def build_config(mailer, otp_app, optional_overrides \\ %{}) do
    otp_app
    |> Application.fetch_env!(mailer)
    |> Map.new()
    |> Map.merge(optional_overrides)
    |> handle_adapter_config
  end

  defp handle_adapter_config(base_config = %{adapter: adapter}) do
    adapter.handle_config(base_config)
    |> Map.put_new(:deliver_later_strategy, Bamboo.TaskSupervisorStrategy)
  end
end
