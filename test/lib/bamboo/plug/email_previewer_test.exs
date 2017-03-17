defmodule Bamboo.EmailPreviewerTest do
  use ExUnit.Case
  use Plug.Test
  import Bamboo.Factory

  defmodule AppRouter do
    use Plug.Router

    plug :match
    plug :dispatch

    forward "/email_previews", to: Bamboo.EmailPreviewPlug
  end

  test "shows all the available emails" do
    conn = conn(:get, "/email_previews")

    conn = AppRouter.call(conn, nil)
    assert conn.status == 200
    assert conn.resp_body =~ "Please select an email"
    # assert html_response(conn, 200) =~ "Customer Email"
    # assert html_response(conn, 200) =~ "Guest Email"
  end
end
