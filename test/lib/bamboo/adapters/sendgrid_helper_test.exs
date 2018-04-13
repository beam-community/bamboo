defmodule Bamboo.SendGridHelperTest do
  use ExUnit.Case

  import Bamboo.SendGridHelper

  @template_id "80509523-83de-42b6-a2bf-54b7513bd2aa"

  setup do
    {:ok, email: Bamboo.Email.new_email()}
  end

  test "with_template/2 adds the correct template", %{email: email} do
    email = email |> with_template(@template_id)
    assert email.private[:send_grid_template] == %{template_id: @template_id}
  end

  test "with_template/2 raises on non-UUID `template_id`", %{email: email} do
    assert_raise RuntimeError, fn ->
      email |> with_template("not a UUID")
    end
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
      email |> substitute(:name, "Jon Snow")
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

  test "with_categories/2 adds the correct property", %{email: email} do
    email = email |> with_categories(["category-1"])
    assert email.private[:categories] != nil
    assert is_list(email.private[:categories])
    assert length(email.private[:categories]) == 1
  end

  test "with_categories/2 concatenates multiple lists", %{email: email} do
    email = email |> with_categories(["category-1"]) |> with_categories(["category-2", "category-3"])
    assert length(email.private[:categories]) == 3
  end

  test "with_categories/2 removes duplicate entries", %{email: email} do
    email = email |> with_categories(["category-1"]) |> with_categories(["category-2", "category-1"])
    assert length(email.private[:categories]) == 2
  end

  test "with_categories/2 only sends the first 10 entries", %{email: email} do
    email = email |> with_categories(["category-1", "category-2", "category-3", "category-4", "category-5", "category-6", "category-7", "category-8", "category-9", "category-10", "category-11"])
    assert length(email.private[:categories]) == 10
  end
end
