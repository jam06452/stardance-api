defmodule StardanceWeb.API.V2Controller do
  use StardanceWeb, :controller

  import StardanceWeb.API.Helpers, only: [send_error: 2, parse_pagination_params: 1]

  # ── Comments ──────────────────────────────────────────────────────────

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

  # ── User projects (paginated) ─────────────────────────────────────────

  def user_projects(conn, params) do
    username = params["username"]
    opts = parse_pagination_params(params)

    case Stardance.DB.list_user_projects(username, opts) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end
end
