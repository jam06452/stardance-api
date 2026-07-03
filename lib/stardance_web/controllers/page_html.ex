defmodule StardanceWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use StardanceWeb, :html

  embed_templates "page_html/*"

  attr :user, :map, default: nil

  def profile_picture(assigns) do
    ~H"""
    <%= if @user && @user.avatar do %>
      <img
        src={@user.avatar}
        class="h-full w-full object-cover"
        alt={profile_picture_alt(@user)}
        draggable="false"
      />
    <% else %>
      <div class="h-full w-full bg-gray-300 flex items-center justify-center">
        <span class="text-gray-500 text-4xl">?</span>
      </div>
    <% end %>
    """
  end

  defp profile_picture_alt(user), do: "#{display_name(user)}'s profile picture"

  def display_name(nil), do: "Unknown"
  def display_name(user), do: user.display_name || user.name || user.email || "Unknown"
end
