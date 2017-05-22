defmodule Mix.Tasks.Bamboo.StartSentEmailViewer do
  use Mix.Task

  @moduledoc false

  # This coud be used in the future by the public, but right now it's only
  # suitable for development.

  def run(_) do
    Mix.Task.run "app.start"
    {:ok, _} = Application.ensure_all_started(:cowboy)
    Plug.Adapters.Cowboy.http Bamboo.SentEmailViewerPlug, [], port: 4003

    for index <- 0..5 do
      Bamboo.Email.new_email(
        from: "me@gmail.com",
        to: "someone@foo.com",
        subject: "#{index} - This is a long subject for testing truncation",
        html_body: """
        Check different tag <strong>styling</strong>

        <ul>
          <li>List item</li>
        </ul>

        <ol>
          <li>List item</li>
        </ol>
        """,
        text_body: """
        This is the text part of an email. It should be pretty
        long to see how it expands on to the next line

        Sincerely,
        Me
        """
      )
      |> Bamboo.Mailer.normalize_addresses
      |> Bamboo.SentEmail.push
    end

    IO.puts "Running sent email viewer on port 4003"
    no_halt()
  end

  defp no_halt do
    unless iex_running?(), do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
