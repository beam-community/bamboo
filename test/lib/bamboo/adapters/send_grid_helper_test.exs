defmodule Bamboo.SendGridHelperTest do
  use ExUnit.Case

  import Bamboo.SendGridHelper

  @template_id "80509523-83de-42b6-a2bf-54b7513bd2aa"
  @ip_pool_name "my-ip-pool-name"

  setup do
    {:ok, email: Bamboo.Email.new_email()}
  end

  test "with_template/2 adds the correct template", %{email: email} do
    email = with_template(email, @template_id)
    assert email.private[:send_grid_template] == %{template_id: @template_id}
  end

  test "with_template/2 uses the last specified template", %{email: email} do
    last_template_id = "355d0197-ecf5-4268-aa8b-2c0502aec406"
    email = email |> with_template(@template_id) |> with_template(last_template_id)
    assert email.private[:send_grid_template][:template_id] == last_template_id
  end

  test "substitute/3 adds the specified tags", %{email: email} do
    email = email |> substitute("%name%", "Jon Snow") |> substitute("%location%", "Westeros")

    assert email.private[:send_grid_template] == %{
             substitutions: %{
               "%name%" => "Jon Snow",
               "%location%" => "Westeros"
             }
           }
  end

  test "substitute/3 raises on non-binary tag", %{email: email} do
    assert_raise RuntimeError, fn ->
      substitute(email, :name, "Jon Snow")
    end
  end

  test "is structured correctly", %{email: email} do
    email = email |> with_template(@template_id) |> substitute("%name%", "Jon Snow")

    assert email.private[:send_grid_template] == %{
             template_id: @template_id,
             substitutions: %{
               "%name%" => "Jon Snow"
             }
           }
  end

  test "is non-dependent on function call ordering", %{email: email} do
    email_1 = email |> with_template(@template_id) |> substitute("%name%", "Jon Snow")
    email_2 = email |> substitute("%name%", "Jon Snow") |> with_template(@template_id)
    assert email_1 == email_2
  end

  test "dynamic_field/3 adds the specified fields", %{email: email} do
    user = %{
      name: "Jon Snow",
      email: "thekinginthenorth@thestarks.com"
    }

    email =
      email
      |> add_dynamic_field("name", "Jon Snow")
      |> add_dynamic_field("location", "Westeros")
      |> add_dynamic_field("user", user)

    assert email.private[:send_grid_template] == %{
             dynamic_template_data: %{
               "name" => "Jon Snow",
               "location" => "Westeros",
               "user" => user
             }
           }
  end

  test "dynamic_field/3 should work with atoms", %{email: email} do
    email =
      add_dynamic_field(email, :name, "Jon Snow")

    assert email.private[:send_grid_template] == %{
             dynamic_template_data: %{
               "name" => "Jon Snow"
             }
           }
  end

  test "with_categories/2 adds the correct property", %{email: email} do
    email = with_categories(email, ["category-1"])
    assert email.private[:categories] != nil
    assert is_list(email.private[:categories])
    assert length(email.private[:categories]) == 1
  end

  test "with_categories/2 concatenates multiple lists", %{email: email} do
    email =
      email |> with_categories(["category-1"]) |> with_categories(["category-2", "category-3"])

    assert length(email.private[:categories]) == 3
  end

  test "with_categories/2 removes duplicate entries", %{email: email} do
    email =
      email |> with_categories(["category-1"]) |> with_categories(["category-2", "category-1"])

    assert length(email.private[:categories]) == 2
  end

  test "with_categories/2 only sends the first 10 entries", %{email: email} do
    email =
      with_categories(email, [
        "category-1",
        "category-2",
        "category-3",
        "category-4",
        "category-5",
        "category-6",
        "category-7",
        "category-8",
        "category-9",
        "category-10",
        "category-11"
      ])

    assert length(email.private[:categories]) == 10
  end

  test "with_asm_group_id/2 adds the correct property", %{email: email} do
    email = with_asm_group_id(email, 1234)
    assert email.private[:asm_group_id] == 1234
  end

  test "with_asm_group_id/2 raises on non-integer id", %{email: email} do
    assert_raise RuntimeError, fn ->
      with_asm_group_id(email, "1234")
    end
  end

  test "with_bypass_list_management/2 adds the correct property", %{email: email} do
    email = with_bypass_list_management(email, true)
    assert email.private[:bypass_list_management] == true
  end

  test "with_bypass_list_management/2 raises on non-boolean parameter", %{email: email} do
    assert_raise RuntimeError, fn ->
      with_bypass_list_management(email, 1)
    end
  end


  test "with_bypass_unsubscribe_management/2 adds the correct property", %{email: email} do
    email = email |> with_bypass_unsubscribe_management(true)
    assert email.private[:bypass_unsubscribe_management] == true
  end

  test "with_bypass_unsubscribe_management/2 raises on non-boolean parameter", %{email: email} do
    assert_raise RuntimeError, fn ->
      email |> with_bypass_unsubscribe_management(1)
    end
  end

  test "with_google_analytics/3 with utm_params", %{email: email} do
    utm_params = %{
      utm_source: "source",
      utm_medium: "medium",
      utm_campaign: "campaign",
      utm_term: "term",
      utm_content: "content"
    }

    email = with_google_analytics(email, true, utm_params)

    assert email.private[:google_analytics_enabled] == true
    assert email.private[:google_analytics_utm_params] == utm_params
  end

  test "with_google_analytics/3 with enabled set false", %{email: email} do
    email = with_google_analytics(email, false)

    assert email.private[:google_analytics_enabled] == false
    assert email.private[:google_analytics_utm_params] == %{}
  end

  test "with_google_analytics/3 raises on non-boolean enabled parameter", %{email: email} do
    utm_params = %{
      utm_source: "source"
    }

    assert_raise RuntimeError, fn ->
      with_google_analytics(email, 1, utm_params)
    end
  end

  test "with_click_tracking/2 with utm_params", %{email: email} do
    email = with_click_tracking(email, true)

    assert email.private[:click_tracking_enabled] == true
  end

  test "with_click_tracking/2 with enabled set false", %{email: email} do
    email = with_click_tracking(email, false)

    assert email.private[:click_tracking_enabled] == false
  end

  test "with_click_tracking/2 raises on non-boolean enabled parameter", %{email: email} do
    assert_raise RuntimeError, fn ->
      with_click_tracking(email, 1)
    end
  end

  test "with_subscription_tracking/2 with enabled set to true", %{email: email} do
    email = with_subscription_tracking(email, true)

    assert email.private[:subscription_tracking_enabled] == true
  end

  test "with_subscription_tracking/2 with enabled set false", %{email: email} do
    email = with_subscription_tracking(email, false)

    assert email.private[:subscription_tracking_enabled] == false
  end

  test "with_subscription_tracking/2 raises on non-boolean enabled parameter", %{email: email} do
    assert_raise RuntimeError, fn ->
      with_subscription_tracking(email, 1)
    end
  end

  describe "with_send_at/2" do
    test "adds the correct property for a DateTime input", %{email: email} do
      {:ok, datetime, _} = DateTime.from_iso8601("2020-01-31T15:46:00Z")
      email = with_send_at(email, datetime)
      assert email.private[:sendgrid_send_at] == 1_580_485_560
    end

    test "adds the correct property for an integer input", %{email: email} do
      timestamp = 1_580_485_560
      email = with_send_at(email, timestamp)
      assert email.private[:sendgrid_send_at] == 1_580_485_560
    end

    test "raises on incorrect input", %{email: email} do
      assert_raise RuntimeError, fn ->
        with_send_at(email, "truck")
      end
    end
  end

  test "with_ip_pool_name/2 adds the ip_pool_name", %{email: email} do
    email = with_ip_pool_name(email, @ip_pool_name)
    assert email.private[:ip_pool_name] == @ip_pool_name
  end

  test "with_custom_args/2 merges multiple maps", %{email: email} do
    email =
      email
      |> with_custom_args(%{new_arg_1: "new arg 1", new_arg_2: "new arg 2"})
      |> with_custom_args(%{new_arg_3: "new arg 3"})

    assert map_size(email.private[:custom_args]) == 3
  end

  test "with_custom_args/2 overrides duplicate entries", %{email: email} do
    email =
      email
      |> with_custom_args(%{new_arg_1: "new arg 1"})
      |> with_custom_args(%{new_arg_1: "latest new arg 1", new_arg_2: "new arg 2"})

    assert map_size(email.private[:custom_args]) == 2
  end

  test "with_custom_args/2 raises on non-map parameter", %{email: email} do
    assert_raise RuntimeError, fn ->
      with_custom_args(email, ["new arg"])
    end
  end
end
