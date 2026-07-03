defmodule StardanceWeb.Plugs.Authenticate do
  @moduledoc """
  A plug that requires a signed-in user. Redirects to /signin when no
  authenticated user is found in the session.
  """

  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :current_user_id) do
      nil ->
        conn
        |> put_flash(:error, "Please sign in to continue.")
        |> redirect(to: "/signin")
        |> halt()

      _user_id ->
        conn
    end
  end
end
