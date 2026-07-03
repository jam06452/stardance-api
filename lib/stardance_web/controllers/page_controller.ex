defmodule StardanceWeb.PageController do
  use StardanceWeb, :controller

  alias Stardance.Repo
  alias Stardance.Schema.AuthUser

  import Ecto.Query

  def lander(conn, _params) do
    endorsed_users =
      Repo.all(
        from a in AuthUser,
          where: a.endorsed == true,
          select: %{display_name: a.display_name, avatar: a.avatar}
      )

    render(conn, :lander, endorsed_users: endorsed_users)
  end

  def signin(conn, _params) do
    render(conn, :signin)
  end

  def docs(conn, _params) do
    render(conn, :docs)
  end

  def dash(conn, _params) do
    render(conn, :dash)
  end
end
