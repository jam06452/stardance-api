defmodule StardanceWeb.API.V1Controller do
  use StardanceWeb, :controller

  def projects(conn, %{"id" => id}) do
    case Stardance.DB.get_project(id) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def users(conn, %{"username" => username}) do
    case Stardance.DB.get_user(username) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_devlog(conn, %{"id" => project_id, "devlog_id" => devlog_id}) do
    case Stardance.DB.get_project_devlog(project_id, devlog_id) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def devlogs(conn, %{"id" => id}) do
    case Stardance.DB.get_devlog_by_id(id) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  defp send_error(conn, :not_found) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Resource not found"})
  end

  defp send_error(conn, 404) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "Resource not found"})
  end

  defp send_error(conn, status) when is_integer(status) do
    conn
    |> put_status(status)
    |> json(%{error: "Request failed with status #{status}"})
  end

  defp send_error(conn, reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: inspect(reason)})
  end
end
