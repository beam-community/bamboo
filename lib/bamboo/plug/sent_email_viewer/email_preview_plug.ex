defmodule Bamboo.SentEmailViewerPlug do
  @moduledoc """
  A plug that can be used in your router to see delivered emails.

  This plug allows you to view all delivered emails. To see emails you must use
  the `Bamboo.LocalAdapter`.

  ## Using with Plug or Phoenix

      # Make sure you are using Bamboo.LocalAdapter in your config
      config :my_app, MyApp.Mailer,
        adapter: Bamboo.LocalAdapter

      # In your Router
      defmodule MyApp.Router do
        use Phoenix.Router # or use Plug.Router if you're not using Phoenix

        if Mix.env == :dev do
          # If using Phoenix
          forward "/sent_emails", Bamboo.SentEmailViewerPlug

          # If using Plug.Router, make sure to add the `to`
          forward "/sent_emails", to: Bamboo.SentEmailViewerPlug
        end
      end

  Now if you visit your app at `/sent_emails` you will see a list of delivered
  emails.
  """
  use Plug.Router

  require EEx

  alias Bamboo.SentEmail

  no_emails_template = Path.join(__DIR__, "no_emails.html.eex")
  EEx.function_from_file(:defp, :no_emails, no_emails_template)

  index_template = Path.join(__DIR__, "index.html.eex")
  EEx.function_from_file(:defp, :index, index_template, [:assigns])

  not_found_template = Path.join(__DIR__, "email_not_found.html.eex")
  EEx.function_from_file(:defp, :not_found, not_found_template, [:assigns])

  plug(:match)
  plug(:dispatch)

  get "/" do
    if Enum.empty?(all_emails()) do
      render_no_emails(conn)
    else
      render_index(conn, newest_email())
    end
  end

  get "/:id" do
    if email = SentEmail.get(id) do
      render_index(conn, email)
    else
      render_not_found(conn)
    end
  end

  get "/:id/html" do
    if email = SentEmail.get(id) do
      email = rewrite_html_body_cids(email)

      conn
      |> Plug.Conn.put_resp_content_type("text/html")
      |> send_resp(:ok, email.html_body || "")
    else
      render_not_found(conn)
    end
  end

  get "/:id/attachments/:index" do
    with %Bamboo.Email{} = email <- SentEmail.get(id),
         %Bamboo.Attachment{} = attachment <- Enum.at(email.attachments, String.to_integer(index)) do
      conn
      |> Plug.Conn.put_resp_header(
        "content-disposition",
        "inline; filename=\"#{attachment.filename}\""
      )
      |> Plug.Conn.put_resp_content_type(attachment.content_type)
      |> send_resp(:ok, attachment.data)
    else
      _ ->
        render_not_found(conn)
    end
  end

  defp all_emails do
    SentEmail.all()
  end

  defp newest_email do
    List.first(all_emails())
  end

  defp render_no_emails(conn) do
    send_html(conn, :ok, no_emails())
  end

  defp render_not_found(conn) do
    assigns = %{base_path: base_path(conn)}
    send_html(conn, :not_found, not_found(assigns))
  end

  defp render_index(conn, email) do
    assigns = %{
      conn: conn,
      base_path: base_path(conn),
      emails: all_emails(),
      selected_email: email
    }

    send_html(conn, :ok, index(assigns))
  end

  defp send_html(conn, status, body) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> send_resp(status, body)
  end

  defp base_path(%{script_name: []}), do: ""

  defp base_path(%{script_name: script_name}) do
    "/" <> Enum.join(script_name, "/")
  end

  defp rewrite_html_body_cids(%{html_body: nil} = email), do: email

  defp rewrite_html_body_cids(%{html_body: html_body} = email) do
    html =
      String.replace(html_body, ~r/cid:[^'"]+/, fn "cid:" <> id = cid ->
        case Enum.find_index(email.attachments, &(&1.content_id == id)) do
          nil -> cid
          i -> "/sent_emails/#{email.private.local_adapter_id}/attachments/#{i}"
        end
      end)

    %{email | html_body: html}
  end
end
