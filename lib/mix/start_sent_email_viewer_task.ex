defmodule Mix.Tasks.Bamboo.StartSentEmailViewer do
  use Mix.Task

  @moduledoc false

  # This could be used in the future by the public, but right now it's only
  # suitable for development.

  def run(_) do
    Mix.Task.run("app.start")
    {:ok, _} = Application.ensure_all_started(:cowboy)
    Plug.Adapters.Cowboy.http(Bamboo.SentEmailViewerPlug, [], port: 4003)

    for index <- 0..5 do
      Bamboo.Email.new_email(
        from: "me@gmail.com",
        to: "someone@foo.com",
        subject: "#{index} - <em>This</em> is a long subject for testing truncation",
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
        Me and <em>html tag</em>
        """
      )
      |> add_attachments(index)
      |> Bamboo.Mailer.normalize_addresses()
      |> Bamboo.SentEmail.push()
    end

    IO.puts("Running sent email viewer on port 4003")
    no_halt()
  end

  defp add_attachments(email, count) do
    # First attachment will be an image, others will be docx files.
    Enum.reduce(count..0, email, fn
      0, email ->
        email

      1, email ->
        path = Path.join(__DIR__, "../../logo/logo.png")
        label = "bamboo-logo"
        Bamboo.Email.put_attachment(email, path, filename: "#{label}.png")

      index, email ->
        path = Path.join(__DIR__, "../../test/support/attachment.docx")
        label = "attachment-#{index}"
        Bamboo.Email.put_attachment(email, path, filename: "#{label}.docx")
    end)
  end

  defp no_halt do
    unless iex_running?(), do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?()
  end
end
