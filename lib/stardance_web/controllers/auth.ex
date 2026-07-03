defmodule Stardance.AuthController do
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias Stardance.Repo
  alias Stardance.Schema.AuthUser

  def on_success(conn, user) do
    attrs = %{
      uid: user.uid,
      email: user.email,
      name: user.name,
      slack_id: user.slack_id,
      provider: user.provider
    }

    {:ok, auth_user} =
      case Repo.get_by(AuthUser, uid: user.uid) do
        nil ->
          %AuthUser{}
          |> AuthUser.changeset(attrs)
          |> Repo.insert()

        existing ->
          existing
          |> AuthUser.changeset(attrs)
          |> Repo.update()
      end

    conn
    |> clear_session()
    |> put_session(:current_user_id, auth_user.id)
    |> delete_session(:amur_session_params)
    |> redirect(to: "/dash")
  end

  def on_failure(conn, reason) do
    IO.inspect(reason, label: "Auth failure")

    conn
    |> redirect(to: "/")
  end
end
