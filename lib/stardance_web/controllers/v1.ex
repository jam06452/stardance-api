defmodule StardanceWeb.API.V1Controller do
  use StardanceWeb, :controller

  def projects(conn, %{"id" => id}) do
    data = Stardance.Utils.get_project(id)
    json(conn, data)
  end

  def users(conn, %{"username" => username}) do
    data = Stardance.Utils.get_user(username)
    json(conn, data)
  end
end
