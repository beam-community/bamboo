defmodule Bamboo.SendGridAdapterTest do
  use ExUnit.Case
  alias Bamboo.Email
  alias Bamboo.SendGridAdapter
  alias Bamboo.Test.User

  @good_api_key "123_abc"
  @config %{adapter: SendGridAdapter, api_key: @good_api_key}
  @config_with_bad_key %{adapter: SendGridAdapter, api_key: nil}
  @config_with_env_var_key %{adapter: SendGridAdapter, api_key: {:system, "SENDGRID_API"}}
  @config_with_env_var_tuple %{
    adapter: SendGridAdapter,
    api_key: {Bamboo.SendGridAdapterTest, :sendgrid_secret, []}
  }
  @config_with_env_var_tuple_direct %{
    adapter: SendGridAdapter,
    api_key: &Bamboo.SendGridAdapterTest.sendgrid_secret/0
  }

  @config_with_sandbox_enabled %{adapter: SendGridAdapter, api_key: @good_api_key, sandbox: true}

  defmodule FakeSendgrid do
    use Plug.Router

    plug(
      Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Jason
    )

    plug(:match)
    plug(:dispatch)

    def start_server(parent) do
      Agent.start_link(fn -> Map.new() end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :sendgrid_base_uri, "http://localhost:#{port}")
      Plug.Adapters.Cowboy.http(__MODULE__, [], port: port, ref: __MODULE__)
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown(__MODULE__)
    end

    post "/mail/send" do
      case get_in(conn.params, ["from", "email"]) do
        "INVALID_EMAIL" -> conn |> send_resp(500, "Error!!") |> send_to_parent
        _ -> conn |> send_resp(200, "SENT") |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn set -> Map.get(set, :parent) end)
      send(parent, {:fake_sendgrid, conn})
      conn
    end
  end

  @doc """
  This is a private function that is referenced in `Bamboo.SendGridAdapterTest`
  to test the config usage example of having a dynamic key
  """
  def sendgrid_secret(), do: @good_api_key

  setup do
    FakeSendgrid.start_server(self())

    on_exit(fn ->
      FakeSendgrid.shutdown()
    end)

    :ok
  end

  describe "API key section" do
    test "raises if the api key is nil" do
      assert_raise ArgumentError, ~r/no API key set/, fn ->
        new_email(from: "foo@bar.com") |> SendGridAdapter.deliver(@config_with_bad_key)
      end

      assert_raise ArgumentError, ~r/no API key set/, fn ->
        SendGridAdapter.handle_config(%{})
      end
    end

    test "can have a tuple resolution" do
      config = SendGridAdapter.handle_config(@config_with_env_var_tuple)
      assert config[:api_key] == @good_api_key
    end

    test "can have an anonymous function resolution" do
      config = SendGridAdapter.handle_config(@config_with_env_var_tuple_direct)
      assert config[:api_key] == @good_api_key
    end

    test "can read the api key from an ENV var" do
      System.put_env("SENDGRID_API", @good_api_key)
      config = SendGridAdapter.handle_config(@config_with_env_var_key)

      assert config[:api_key] == @good_api_key
    end

    test "raises if an invalid ENV var is used for the API key" do
      System.delete_env("SENDGRID_API")

      assert_raise ArgumentError, ~r/no API key set/, fn ->
        new_email(from: "foo@bar.com") |> SendGridAdapter.deliver(@config_with_env_var_key)
      end

      assert_raise ArgumentError, ~r/no API key set/, fn ->
        SendGridAdapter.handle_config(@config_with_env_var_key)
      end
    end
  end

  test "deliver/2 returns an {:ok, response}" do
    {:ok, response} = new_email() |> SendGridAdapter.deliver(@config)

    assert %{status_code: 200, headers: _, body: _} = response
  end

  test "deliver/2 sends the to the right url" do
    new_email() |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{request_path: request_path}}

    assert request_path == "/mail/send"
  end

  test "deliver/2 sends from, html and text body, subject, headers and attachment" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject",
        text_body: "TEXT BODY",
        html_body: "HTML BODY"
      )
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Email.put_attachment(Path.join(__DIR__, "../../../support/attachment.txt"))

    email |> SendGridAdapter.deliver(@config)

    assert SendGridAdapter.supports_attachments?()
    assert_receive {:fake_sendgrid, %{params: params, req_headers: headers}}

    assert params["from"]["name"] == email.from |> elem(0)
    assert params["from"]["email"] == email.from |> elem(1)
    assert params["subject"] == email.subject
    assert Enum.member?(params["content"], %{"type" => "text/plain", "value" => email.text_body})
    assert Enum.member?(params["content"], %{"type" => "text/html", "value" => email.html_body})
    assert Enum.member?(headers, {"authorization", "Bearer #{@config[:api_key]}"})

    assert params["attachments"] == [
             %{
               "type" => "text/plain",
               "filename" => "attachment.txt",
               "content" => "VGVzdCBBdHRhY2htZW50Cg=="
             }
           ]
  end

  test "deliver/2 correctly custom args" do
    email = new_email()

    email
    |> Email.put_private(:custom_args, %{post_code: "123"})
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    personalization = List.first(params["personalizations"])
    assert personalization["custom_args"] == %{"post_code" => "123"}
  end

  test "deliver/2 without custom args" do
    email = new_email()

    email
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    personalization = List.first(params["personalizations"])
    assert personalization["custom_args"] == nil
  end

  test "deliver/2 correctly formats recipients" do
    email =
      new_email(
        to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
        cc: [{"CC", "cc@bar.com"}],
        bcc: [{"BCC", "bcc@bar.com"}]
      )

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    addressees = List.first(params["personalizations"])

    assert addressees["to"] == [
             %{"name" => "To", "email" => "to@bar.com"},
             %{"email" => "noname@bar.com"}
           ]

    assert addressees["cc"] == [%{"name" => "CC", "email" => "cc@bar.com"}]
    assert addressees["bcc"] == [%{"name" => "BCC", "email" => "bcc@bar.com"}]
  end

  test "deliver/2 correctly handles templates" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_template("a4ca8ac9-3294-4eaf-8edc-335935192b8d")
    |> Bamboo.SendGridHelper.substitute("%foo%", "bar")
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    personalization = List.first(params["personalizations"])
    refute Map.has_key?(params, "content")
    assert params["template_id"] == "a4ca8ac9-3294-4eaf-8edc-335935192b8d"
    assert personalization["substitutions"] == %{"%foo%" => "bar"}
  end

  test "deliver/2 correctly handles ip_pool_name" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_ip_pool_name("my-ip-pool-name")
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert Map.get(params, "ip_pool_name") == "my-ip-pool-name"
  end

  test "deliver/2 correctly handles an asm_group_id" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_asm_group_id(1234)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["asm"]["group_id"] == 1234
  end

  test "deliver/2 correctly handles a bypass_list_management" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_bypass_list_management(true)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["mail_settings"]["bypass_list_management"]["enable"] == true
  end

  test "deliver/2 correctly handles with_google_analytics that's enabled with no utm_params" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_google_analytics(true)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["ganalytics"]["enable"] == true
  end

  test "deliver/2 correctly handles with_google_analytics that's disabled with no utm_params" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_google_analytics(false)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["ganalytics"]["enable"] == false
  end

  test "deliver/2 correctly handles with_google_analytics that's enabled with utm_params" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    utm_params = %{
      utm_source: "source",
      utm_medium: "medium",
      utm_campaign: "campaign",
      utm_term: "term",
      utm_content: "content"
    }

    email
    |> Bamboo.SendGridHelper.with_google_analytics(true, utm_params)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["ganalytics"]["enable"] == true
    assert params["tracking_settings"]["ganalytics"]["utm_source"] == "source"
    assert params["tracking_settings"]["ganalytics"]["utm_medium"] == "medium"
    assert params["tracking_settings"]["ganalytics"]["utm_campaign"] == "campaign"
    assert params["tracking_settings"]["ganalytics"]["utm_term"] == "term"
    assert params["tracking_settings"]["ganalytics"]["utm_content"] == "content"
  end

  test "deliver/2 correctly handles when with_click_tracking is enabled" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_click_tracking(true)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["click_tracking"]["enable"] == true
    assert params["tracking_settings"]["click_tracking"]["enable_text"] == true
  end

  test "deliver/2 correctly handles when with_click_tracking is disabled" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_click_tracking(false)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["click_tracking"]["enable"] == false
    assert params["tracking_settings"]["click_tracking"]["enable_text"] == false
  end

  test "deliver/2 correctly handles when with_subscription_tracking is enabled" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_subscription_tracking(true)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["subscription_tracking"]["enable"] == true
    assert params["tracking_settings"]["subscription_tracking"]["enable_text"] == true
  end

  test "deliver/2 correctly handles when with_subscription_tracking is disabled" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_subscription_tracking(false)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["tracking_settings"]["subscription_tracking"]["enable"] == false
    assert params["tracking_settings"]["subscription_tracking"]["enable_text"] == false
  end

  test "deliver/2 correctly handles a sendgrid_send_at timestamp" do
    email =
      new_email(
        from: {"From", "from@foo.com"},
        subject: "My Subject"
      )

    email
    |> Bamboo.SendGridHelper.with_send_at(1_580_485_560)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["send_at"] == 1_580_485_560
  end

  test "deliver/2 doesn't force a subject" do
    email = new_email(from: {"From", "from@foo.com"})

    email
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    refute Map.has_key?(params, "subject")
  end

  test "deliver/2 correctly formats reply-to from headers" do
    email = new_email(headers: %{"reply-to" => "foo@bar.com"})

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["reply_to"] == %{"email" => "foo@bar.com"}
  end

  test "deliver/2 correctly formats Reply-To from headers" do
    email = new_email(headers: %{"Reply-To" => "foo@bar.com"})

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["reply_to"] == %{"email" => "foo@bar.com"}
  end

  test "deliver/2 correctly formats Reply-To from headers with name and email" do
    email = new_email(headers: %{"Reply-To" => {"Foo Bar", "foo@bar.com"}})

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["reply_to"] == %{"email" => "foo@bar.com", "name" => "Foo Bar"}
  end

  test "deliver/2 correctly formats reply-to from headers with name and email" do
    email = new_email(headers: %{"reply-to" => {"Foo Bar", "foo@bar.com"}})

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["reply_to"] == %{"email" => "foo@bar.com", "name" => "Foo Bar"}
  end

  test "deliver/2 correctly sends headers" do
    email =
      new_email(
        headers: %{
          "In-Reply-To" => "message_id",
          "References" => "message_id"
        }
      )

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}

    assert params["headers"] ==
             %{"In-Reply-To" => "message_id", "References" => "message_id"}
  end

  test "deliver/2 removes 'reply-to' and 'Reply-To' headers" do
    email =
      new_email(
        headers: %{
          "X-Custom-Header" => "ohai",
          "Reply-To" => "something",
          "reply-to" => {"a", "tuple"}
        }
      )

    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}

    refute Map.has_key?(params["headers"], "Reply-To")
    refute Map.has_key?(params["headers"], "reply-to")
  end

  test "deliver/2 omits attachments key if no attachments" do
    email = new_email()
    email |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    refute Map.has_key?(params, "attachments")
  end

  test "deliver/2 handles multiple personalizations" do
    {:ok, dt, _} = DateTime.from_iso8601("2020-01-01 00:00:00Z")

    personalization2 = %{
      bcc: [%{"email" => "bcc2@bar.com", "name" => "BCC2"}],
      cc: [%{"email" => "cc2@bar.com", "name" => "CC2"}],
      custom_args: %{"post_code" => "223"},
      substitutions: %{"%foo%" => "bar2"},
      headers: [%{"X-Fun-Header" => "Fun Value"}],
      to: [
        %{"email" => "to2@bar.com", "name" => "To2"},
        %{"email" => "noname2@bar.com"}
      ],
      send_at: dt
    }

    personalization3 = %{
      custom_args: %{"thinger" => "bob"},
      to: [
        %{"email" => "to3@bar.com", "name" => "To3"}
      ],
      cc: [],
      subject: "Custom subject",
      send_at: 1_580_485_561
    }

    email =
      new_email(
        to: [{"To", "to@bar.com"}, {nil, "noname@bar.com"}],
        cc: [{"CC", "cc@bar.com"}],
        subject: "My Subject",
        bcc: [{"BCC", "bcc@bar.com"}]
      )
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.substitute("%foo%", "bar")
      |> Bamboo.SendGridHelper.with_send_at(1_580_485_562)
      |> Bamboo.SendGridHelper.add_personalizations([personalization2, personalization3])
      |> Email.put_private(:custom_args, %{post_code: "123"})

    email
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    personalizations = params["personalizations"]

    [got_personalization1, got_personalization2, got_personalization3] = personalizations

    assert got_personalization1 == %{
             "bcc" => [%{"email" => "bcc@bar.com", "name" => "BCC"}],
             "cc" => [%{"email" => "cc@bar.com", "name" => "CC"}],
             "custom_args" => %{"post_code" => "123"},
             "substitutions" => %{"%foo%" => "bar"},
             "to" => [
               %{"email" => "to@bar.com", "name" => "To"},
               %{"email" => "noname@bar.com"}
             ],
             "send_at" => 1_580_485_562
           }

    assert got_personalization2 == %{
             "bcc" => [%{"email" => "bcc2@bar.com", "name" => "BCC2"}],
             "cc" => [%{"email" => "cc2@bar.com", "name" => "CC2"}],
             "custom_args" => %{"post_code" => "223"},
             "headers" => [%{"X-Fun-Header" => "Fun Value"}],
             "substitutions" => %{"%foo%" => "bar2"},
             "to" => [
               %{"email" => "to2@bar.com", "name" => "To2"},
               %{"email" => "noname2@bar.com"}
             ],
             "send_at" => 1_577_836_800
           }

    assert got_personalization3 ==
             %{
               "custom_args" => %{"thinger" => "bob"},
               "to" => [
                 %{"email" => "to3@bar.com", "name" => "To3"}
               ],
               "cc" => [],
               "subject" => "Custom subject",
               "send_at" => 1_580_485_561
             }
  end

  test "deliver/2 handles setting params only via personalizations" do
    base_personalization = %{
      bcc: [%{"email" => "bcc@bar.com", "name" => "BCC"}],
      subject: "Here is your email"
    }

    personalizations =
      Enum.map(
        [
          %{to: "one@test.com"},
          %{to: "two@test.com", send_at: 1_580_485_560}
        ],
        &Map.merge(base_personalization, &1)
      )

    email =
      new_email()
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.add_personalizations(personalizations)

    email
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    personalizations = params["personalizations"]

    [got_personalization1, got_personalization2] = personalizations

    assert got_personalization1 == %{
             "bcc" => [%{"email" => "bcc@bar.com", "name" => "BCC"}],
             "subject" => "Here is your email",
             "to" => [%{"email" => "one@test.com"}]
           }

    assert got_personalization2 == %{
             "bcc" => [%{"email" => "bcc@bar.com", "name" => "BCC"}],
             "subject" => "Here is your email",
             "to" => [%{"email" => "two@test.com"}],
             "send_at" => 1_580_485_560
           }
  end

  test "deliver/2 personalizations require a 'to' field" do
    email =
      new_email()
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.add_personalizations([%{subject: "This will fail"}])

    {:error, msg} = email |> SendGridAdapter.deliver(@config)

    assert msg =~ ~r/'to' field/
  end

  test "deliver/2 personalization send_at field must be either DateTime or epoch timestamp" do
    email =
      new_email()
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.add_personalizations([%{to: "foo@bar.com", send_at: "now"}])

    {:error, msg} = email |> SendGridAdapter.deliver(@config)

    assert msg =~ ~r/'send_at' time/
  end

  test "deliver/2 correctly formats email addresses in personalizations" do
    personalization = %{
      to: "joe@bloe.com",
      cc: [{"Baz", "baz@bang.com"}, %User{first_name: "fred", email: "me@flinstones.com"}],
      bcc: [%{"email" => "bcc@bar.com", "name" => "BCC"}, {nil, "foo@bar.com"}],
      subject: "Here is your email"
    }

    email =
      new_email()
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.add_personalizations([personalization])

    email
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    [got_personalization] = params["personalizations"]

    assert got_personalization == %{
             "subject" => "Here is your email",
             "to" => [%{"email" => "joe@bloe.com"}],
             "cc" => [
               %{"name" => "Baz", "email" => "baz@bang.com"},
               %{"name" => "fred", "email" => "me@flinstones.com"}
             ],
             "bcc" => [%{"name" => "BCC", "email" => "bcc@bar.com"}, %{"email" => "foo@bar.com"}]
           }
  end

  test "deliver/2 personalization address-as-map must contain at least an email field" do
    email =
      new_email()
      |> Email.put_header("Reply-To", "reply@foo.com")
      |> Bamboo.SendGridHelper.add_personalizations([%{to: %{"name" => "Lou"}, send_at: "now"}])

    {:error, msg} = email |> SendGridAdapter.deliver(@config)

    assert msg =~ ~r/'email' field/
  end

  test "deliver/2 correctly handles with_custom_args" do
    email = new_email()

    custom_args = %{
      new_arg1: "new arg 1",
      new_arg2: "new arg 2",
      new_arg3: "new arg 3"
    }

    email
    |> Bamboo.SendGridHelper.with_custom_args(custom_args)
    |> SendGridAdapter.deliver(@config)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["custom_args"]["new_arg1"] == "new arg 1"
    assert params["custom_args"]["new_arg2"] == "new arg 2"
    assert params["custom_args"]["new_arg3"] == "new arg 3"
  end

  test "deliver/2 will set sandbox mode correctly" do
    email = new_email()
    email |> SendGridAdapter.deliver(@config_with_sandbox_enabled)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["mail_settings"]["sandbox_mode"]["enable"] == true
  end

  test "deliver/2 with sandbox mode enabled, does not overwrite other mail_settings" do
    email = new_email()

    email
    |> Bamboo.SendGridHelper.with_bypass_list_management(true)
    |> SendGridAdapter.deliver(@config_with_sandbox_enabled)

    assert_receive {:fake_sendgrid, %{params: params}}
    assert params["mail_settings"]["sandbox_mode"]["enable"] == true
    assert params["mail_settings"]["bypass_list_management"]["enable"] == true
  end

  test "returns an error if the response is not a success" do
    email = new_email(from: "INVALID_EMAIL")

    {:error, error} = email |> SendGridAdapter.deliver(@config)

    assert %Bamboo.ApiError{} = error
  end

  test "removes api key from error output" do
    email = new_email(from: "INVALID_EMAIL")

    {:error, error} = email |> SendGridAdapter.deliver(@config)

    assert error.message =~ ~r/"key" => "\[FILTERED\]"/
  end

  defp new_email(attrs \\ []) do
    attrs = Keyword.merge([from: "foo@bar.com", to: []], attrs)
    Email.new_email(attrs) |> Bamboo.Mailer.normalize_addresses()
  end
end
