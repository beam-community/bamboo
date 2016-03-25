defmodule Bamboo.EmailPreviewPlug do
  use Plug.Router
  alias Bamboo.SentEmail

  @moduledoc """
  A plug that can be used in your router to see delivered emails.

  This plug allows you to view all deliver emails. To see emails you must use
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
          forward "/sent_emails", Bamboo.EmailPreviewPlug

          # If using Plug.Router, make sure to add the `to`
          forward "/sent_emails", to: Bamboo.EmailPreviewPlug
        end
      end

  Now if you visit your app at `/sent_emails` you will see a list of delivered
  emails.
  """

  plug :match
  plug :dispatch

  get "/" do
    if Enum.empty?(all_emails) do
      conn |> render(:ok, "no_emails.html")
    else
      conn |> render(:ok, "index.html", emails: all_emails, selected_email: newest_email)
    end
  end

  get "/:id" do
    if email = SentEmail.get(id) do
      conn |> render(:ok, "index.html", emails: all_emails, selected_email: email)
    else
      conn |> render(:not_found, "email_not_found.html")
    end
  end

  defp all_emails do
    SentEmail.all
  end

  defp newest_email do
    all_emails |> List.first
  end

  defp render(conn, status, template_name, assigns \\ []) do
    path = Path.join(__DIR__, template_name <> ".eex")
    assigns = Keyword.merge(assigns, conn: conn, base_path: base_path(conn))
    rendered_template = EEx.eval_file(path, assigns: assigns)
    send_resp(conn, status, rendered_template)
  end

  defp base_path(%{script_name: []}), do: ""
  defp base_path(%{script_name: script_name}) do
    "/" <> Enum.join(script_name, "/")
  end
end
