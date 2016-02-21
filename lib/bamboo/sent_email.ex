defmodule Bamboo.SentEmail do
  @moduledoc """
  Used for storing and retrieving sent emails when used with
  Bamboo.Adapters.Local

  When emails are sent with the Bamboo.Adapters.Local, they are stored in
  Bamboo.SentEmail. Use the following function to store and retrieve the emails.
  Remember to start the Bamboo app by adding it to the app list in mix.exs or
  starting it with Application.ensure_all_started(:bamboo)
  """

  defmodule DeliveriesError do
    defexception [:message]

    def exception(emails) do
      message = """
      SentEmail.one/1 expected to find one email, got #{Enum.count(emails)}:

      #{email_list(emails)}

      This function is used when you expect only one email to have been sent. If
      you meant to send more than one email, you can call
      SentEmail.all/0 to get all sent emails.

      For example: SentEmail.all |> List.first
      """
      %DeliveriesError{message: message}
    end

    defp email_list(emails) do
      emails
      |> Enum.map(&inspect/1)
      |> Enum.join("\n")
    end
  end

  defmodule NoDeliveriesError do
    defexception [:message]

    def exception(_) do
      message = "SentEmail.one/1 expected to find one email, but got none."
      %NoDeliveriesError{message: message}
    end
  end

  @doc "Starts the SentEmail Agent"
  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc "Returns a list of all sent emails"
  def all do
    Agent.get(__MODULE__, fn(emails) -> emails end)
  end

  @doc "Adds an email to the list of sent emails"
  def push(email) do
    Agent.update(__MODULE__, fn(emails) ->
      emails ++ [email]
    end)
  end

  @doc """
  Returns exactly one sent email

  Raises `NoDeliveriesError` if there are no emails. Raises `DeliveriesError` if
  there are 2 or more emails.
  """
  def one do
    case all do
      [email] -> email
      [] -> raise NoDeliveriesError
      emails -> raise DeliveriesError, emails
    end
  end

  @doc "Clears all sent emails"
  def reset do
    Agent.update(__MODULE__, fn(_) ->
      []
    end)
  end
end
