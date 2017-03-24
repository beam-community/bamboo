defmodule Mix.Tasks.Bamboo.StartEmailPreviewer do
  use Mix.Task
  @port 4004
  @shortdoc "Start the email preview server"
  def run(_) do
    Mix.Task.run "app.start"
    Application.put_env(:bamboo, :email_preview_module, __MODULE__)
    {:ok, _} = Application.ensure_all_started(:cowboy)
    Plug.Adapters.Cowboy.http Bamboo.EmailPreviewPlug, [], port: @port

    IO.puts "Running email preview on port #{@port}"
    no_halt()
  end

  defp no_halt do
    unless iex_running?(), do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end

  def previews do
    [
      %{
        path: "customer_email",
        name: "Customer Email",
        email: fn ->
          %{html_body: "Hi Customer HTML", text_body: "Hi Customer Text"}
        end,
      }, %{
        path: "guest_email",
        name: "Guest Email",
        email: fn ->
          %{html_body: "Hi Guest HTML", text_body: "Hi Guest Text"}
        end,
      },
    ]
  end
end
