defmodule Bamboo.Phoenix do
  defmacro __using__(view: view_module) do
    verify_phoenix_dep
    quote do
      import Bamboo.Email
      @email_view_module unquote(view_module)

      def render(email, template, assigns \\ []) do
        Bamboo.Phoenix.render_templates(@email_view_module, email, template, assigns)
      end
    end
  end

  defp verify_phoenix_dep do
    unless Code.ensure_loaded?(Phoenix) do
      raise "You tried to use Bamboo.Phoenix, but Phoenix module is not loaded. " <>
      "Please add phoenix to your dependencies."
    end
  end

  def render_templates(view, email, template, assigns) do
    email
    |> Map.put(:html_body, render_email(view, template <> ".html", assigns))
    |> Map.put(:text_body, render_email(view, template <> ".text", assigns))
    |> raise_if_nothing_rendered
  end

  defp render_email(view, template, assigns) do
    Phoenix.View.render_existing(view, template, assigns)
    |> encode(template)
  end

  defp encode(nil, _), do: ""
  defp encode(content, template) do
    if encoder = Phoenix.Template.format_encoder(template) do
      encoder.encode_to_iodata!(content) |> IO.iodata_to_binary
    else
      content
    end
  end

  defp raise_if_nothing_rendered(%{html_body: "", text_body: ""} = email) do
    raise ArgumentError, """
    Expected email to have at least an html_body or a text_body, instead got:
    #{inspect email}

    Be sure to create either a text or html template.
    """
  end
  defp raise_if_nothing_rendered(email), do: email
end
