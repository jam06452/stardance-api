defmodule StardanceWeb.API.V1Controller do
  use StardanceWeb, :controller

  def projects(conn, %{"id" => id}) do
    data = Stardance.DB.get_project(id)

    case data do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_resp(conn, reason, "")
    end
  end

  def users(conn, %{"username" => username}) do
    data = Stardance.DB.get_user(username)

    case data do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_resp(conn, reason, "")
    end
  end
end
