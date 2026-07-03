defmodule Stardance.HackatimeBackfill do
  @moduledoc """
  One-shot task that runs on startup to backfill `display_name` on
  `auth_users` records that are missing one. For each such record with a
  `slack_id`, it fetches the hackatime username and updates the row in place.
  Records without a `slack_id` or whose hackatime lookup fails are skipped.
  """
  use Task, restart: :transient

  import Ecto.Query

  alias Stardance.Repo
  alias Stardance.Schema.AuthUser
  alias Stardance.Utils

  def start_link(_arg) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run do
    users =
      Repo.all(
        from u in AuthUser,
          where: is_nil(u.display_name) and not is_nil(u.slack_id) and u.slack_id != ""
      )

    for user <- users do
      case Utils.fetch_hackatime_display_name(user.slack_id) do
        {:ok, username} when is_binary(username) and username != "" ->
          user
          |> AuthUser.changeset(%{display_name: username})
          |> Repo.update()

        _ ->
          :skip
      end
    end

    :ok
  end
end
