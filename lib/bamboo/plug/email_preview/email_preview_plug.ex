defmodule Bamboo.EmailPreviewPlug do
  use Plug.Router
  require EEx
  @moduledoc false

  index_template = Path.join(__DIR__, "index.html.eex")
  EEx.function_from_file(:defp, :index, index_template, [:assigns])

  show_template = Path.join(__DIR__, "show.html.eex")
  EEx.function_from_file(:defp, :show, show_template, [:assigns])

  plug :match
  plug :dispatch

  get "/" do
    assigns = %{
      conn: conn,
      previews: all_previews(),
    }
    conn
    |> send_html(:ok, index(assigns))
  end

  get "/:preview_path/:format" do
    assigns = %{
      conn: conn,
      preview: find_matching_preview(all_previews(), preview_path),
      showing_text: format == "text",
    }
    conn
    |> send_html(:ok, show(assigns))
  end

  defp send_html(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp all_previews do
    Application.fetch_env!(:bamboo, :email_preview_module).previews
  end

  defp find_matching_preview(previews, path) do
    previews |> Enum.find(&(&1.path == path))
  end
end
