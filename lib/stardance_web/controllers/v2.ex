defmodule StardanceWeb.API.V2Controller do
  use StardanceWeb, :controller

  def devlog_comments(conn, %{"id" => id}) do
    devlog_id = String.to_integer(id)

    case Stardance.DB.get_devlog_comments(devlog_id) do
      {:ok, comments} -> json(conn, comments)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_comments(conn, %{"id" => id}) do
    project_id = String.to_integer(id)

    case Stardance.DB.get_project_comments(project_id) do
      {:ok, comments} -> json(conn, comments)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  defp send_error(conn, :not_found) do
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
