defmodule Mix.Tasks.Bamboo.StartEmailPreviewer do
  use Mix.Task

  @shortdoc "Start the email preview server"
  def run(_) do
    Mix.Task.run "app.start"
    {:ok, _} = Application.ensure_all_started(:cowboy)
    Plug.Adapters.Cowboy.http Bamboo.EmailPreviewPlug, [], port: 4003

    IO.puts "Running email preview on port 4003"
    no_halt()
  end

  defp no_halt do
    unless iex_running?(), do: :timer.sleep(:infinity)
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) && IEx.started?
  end
end
