defmodule Stardance.AuthController do
  import Plug.Conn
  import Phoenix.Controller

  alias Stardance.Repo
  alias Stardance.Schema.AuthUser

  def on_success(conn, user) do
    slack_id = user.slack_id

    hackatime_attrs =
      if slack_id not in [nil, ""] do
        case fetch_slack_name(slack_id) do
          {:ok, username} -> %{display_name: username}
          _ -> %{}
        end
      else
        %{}
      end

    cachet_attrs =
      if slack_id not in [nil, ""] do
        case fetch_cachet_info(slack_id) do
          {:ok, %{image_url: image_url}} ->
            %{avatar: Stardance.Utils.shorten(image_url)}

          _ ->
            %{}
        end
      else
        %{}
      end

    attrs =
      %{
        uid: user.uid,
        email: user.email,
        name: user.name,
        slack_id: slack_id,
        provider: user.provider
      }
      |> Map.merge(cachet_attrs)
      |> Map.merge(hackatime_attrs)

    auth_user =
      case Repo.get_by(AuthUser, uid: user.uid) do
        nil ->
          %AuthUser{}
          |> AuthUser.changeset(attrs)
          |> Repo.insert!()

        existing ->
          existing
          |> AuthUser.changeset(attrs)
          |> Repo.update!()
      end

    conn
    |> clear_session()
    |> put_session(:current_user_id, auth_user.id)
    |> delete_session(:amur_session_params)
    |> redirect(to: "/dash")
  end

  def on_failure(conn, reason) do
    require Logger
    Logger.warning("Auth failure: #{inspect(reason)}")

    conn
    |> redirect(to: "/")
  end

  defp fetch_cachet_info(slack_id) do
    Stardance.Utils.fetch_cachet_user(slack_id)
  end

  defp fetch_slack_name(slack_id) do
    Stardance.Utils.fetch_slack_display_name(slack_id)
  end
end
