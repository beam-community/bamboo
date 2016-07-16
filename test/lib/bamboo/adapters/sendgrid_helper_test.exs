defmodule Bamboo.SendgridHelperTest do
  use ExUnit.Case

  import Bamboo.SendgridHelper

  @template_id "80509523-83de-42b6-a2bf-54b7513bd2aa"

  setup do
    {:ok, email: Bamboo.Email.new_email}
  end

  test "with_template/2 adds the correct template", %{email: email} do
    email = email |> with_template(@template_id)
    assert email.private["x-smtpapi"] == %{
        "filters" => %{
          "templates" => %{
            "settings" => %{
              "enable" => 1,
              "template_id" => @template_id
            }
          }
        }
      }
  end

  test "with_template/2 raises on non-UUID `template_id`", %{email: email} do
    assert_raise RuntimeError, fn ->
      email |> with_template("not a UUID")
    end
  end

  test "with_template/2 uses the last specified template", %{email: email} do
    last = "355d0197-ecf5-4268-aa8b-2c0502aec406"
    email = email |> with_template(@template_id) |> with_template(last)
    assert email.private["x-smtpapi"]["filters"]["templates"]["settings"]["template_id"] == last
  end

  test "substitute/3 adds the specified tags", %{email: email} do
    email = email |> substitute("%name%", "Jon Snow") |> substitute("%location%", "Westeros")
    assert email.private["x-smtpapi"] == %{
        "sub" => %{
          "%name%" => ["Jon Snow"],
          "%location%" => ["Westeros"]
        }
      }
  end

  test "substitute/3 raises on non-binary tag", %{email: email} do
    assert_raise RuntimeError, fn ->
      email |> substitute(:name, "Jon Snow")
    end
  end

  test "is structured correctly", %{email: email} do
    email = email |> with_template(@template_id) |> substitute("%name%", "Jon Snow")
    assert email.private["x-smtpapi"] == %{
        "filters" => %{
          "templates" => %{
            "settings" => %{
              "enable" => 1,
              "template_id" => @template_id
            }
          }
        },
        "sub" => %{
          "%name%" => ["Jon Snow"]
        }
      }
  end

  test "is non-dependent on function call ordering", %{email: email} do
    email_1 = email |> with_template(@template_id) |> substitute("%name%", "Jon Snow")
    email_2 = email |> substitute("%name%", "Jon Snow") |> with_template(@template_id)
    assert email_1 == email_2
  end
end
