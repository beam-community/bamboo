defmodule Bamboo.EmailPreviewPlug do
  use Plug.Router
  require EEx
  @moduledoc false

  index_template = Path.join(__DIR__, "index.html.eex")
  EEx.function_from_file(:defp, :index, index_template, [:assigns])

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

  defp send_html(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp all_previews do
    Application.fetch_env!(:bamboo, :email_preview_module).previews
  end
end
