defmodule Bamboo.SentEmail do
  @moduledoc """
  Used for storing and retrieving sent emails when used with `Bamboo.LocalAdapter`.

  When emails are sent with the `Bamboo.LocalAdapter`, they are stored in
  `Bamboo.SentEmail`. Use the functions in this module to store and retrieve the emails.

  Remember to start the Bamboo app by adding it to the app list in `mix.exs` or
  starting it with `Application.ensure_all_started(:bamboo)`
  """

  use Agent

  @id_length 16

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
      message = "expected to find one email, but got none."
      %NoDeliveriesError{message: message}
    end
  end

  @doc "Starts the SentEmail Agent"
  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  @doc """
  Gets the email's id.

  The email must be an email that was sent with `Bamboo.LocalAdapter` or added
  via `Bamboo.SentEmail.push/1`, otherwise the id will not have been set.
  """
  def get_id(%Bamboo.Email{private: %{local_adapter_id: id}}) do
    id
  end

  def get_id(%Bamboo.Email{}) do
    raise """
    SentEmail.get_id/1 expected the email to have an id, but no id was present.

    This is usually because the email was not sent with Bamboo.LocalAdapter
    or wasn't pushed with SentEmail.push/1
    """
  end

  def get_id(email) do
    raise "SentEmail.get_id/1 expected a %Bamboo.Email{}, instead got: #{inspect(email)}"
  end

  @doc """
  Gets an email by id. Returns nil if it can't find a matching email.
  """
  def get(id) do
    do_get(id)
  end

  @doc """
  Gets an email by id. Raises if it can't find one.
  """
  def get!(id) do
    do_get(id) || raise NoDeliveriesError, nil
  end

  defp do_get(id) do
    Enum.find(all(), nil, fn email ->
      email |> get_id |> String.downcase() == String.downcase(id)
    end)
  end

  @doc "Returns a list of all sent emails"
  def all do
    Agent.get(__MODULE__, fn emails -> emails end)
  end

  @doc """
  Adds an email to the list of sent emails.

  Adds an email to the beginning of the sent emails list. Also gives the email
  an id that can be fetched with `Bamboo.SentEmail.get_id/1`.
  """
  def push(email) do
    email = put_rand_id(email)

    Agent.update(__MODULE__, fn emails ->
      [email | emails]
    end)

    email
  end

  defp put_rand_id(email) do
    email |> Bamboo.Email.put_private(:local_adapter_id, rand_id())
  end

  defp rand_id do
    :crypto.strong_rand_bytes(@id_length)
    |> Base.url_encode64()
    |> binary_part(0, @id_length)
  end

  @doc """
  Returns exactly one sent email. Raises if none, or more than one are found

  Raises `NoDeliveriesError` if there are no emails. Raises `DeliveriesError` if
  there are 2 or more emails.
  """
  def one do
    case all() do
      [email] -> email
      [] -> raise NoDeliveriesError
      emails -> raise DeliveriesError, emails
    end
  end

  @doc "Clears all sent emails"
  def reset do
    Agent.update(__MODULE__, fn _ ->
      []
    end)
  end
end
