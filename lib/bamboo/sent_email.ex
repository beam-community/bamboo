defmodule Bamboo.SentEmail do
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

  def start_link do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def all do
    Agent.get(__MODULE__, fn(emails) -> emails end)
  end

  def push(email) do
    Agent.update(__MODULE__, fn(emails) ->
      emails ++ [email]
    end)
  end

  def one do
    case all do
      [email] -> email
      [] -> raise NoDeliveriesError
      emails -> raise DeliveriesError, emails
    end
  end

  def reset do
    Agent.update(__MODULE__, fn(_) ->
      []
    end)
  end
end
