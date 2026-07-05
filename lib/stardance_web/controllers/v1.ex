defmodule StardanceWeb.API.V1Controller do
  use StardanceWeb, :controller

  import StardanceWeb.API.Helpers, only: [send_error: 2, parse_pagination_params: 1]

  # ── Projects ──────────────────────────────────────────────────────────

  def index(conn, params) do
    opts = parse_pagination_params(params)
    {:ok, data} = Stardance.DB.list_projects(Keyword.put(opts, :version, :v1))
    json(conn, data)
  end

  def projects(conn, %{"id" => id}) do
    case Stardance.DB.get_project(id, version: :v1) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_devlogs(conn, params) do
    project_id = String.to_integer(params["id"])
    opts = Keyword.put(parse_pagination_params(params), :version, :v1)

    case Stardance.DB.list_project_devlogs(project_id, opts) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_devlog(conn, %{"id" => project_id, "devlog_id" => devlog_id}) do
    case Stardance.DB.get_project_devlog(project_id, devlog_id, version: :v1) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  # ── Users ─────────────────────────────────────────────────────────────

  def list_users(conn, params) do
    opts = Keyword.put(parse_pagination_params(params), :version, :v1)
    {:ok, data} = Stardance.DB.list_users(opts)
    json(conn, data)
  end

  def users(conn, %{"username" => username}) do
    case Stardance.DB.get_user(username, version: :v1) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def devlogs(conn, %{"id" => id}) do
    case Stardance.DB.get_devlog_by_id(id, version: :v1) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def devlogs_index(conn, params) do
    opts = Keyword.put(parse_pagination_params(params), :version, :v1)
    {:ok, data} = Stardance.DB.list_devlogs(opts)
    json(conn, data)
  end

  def user_projects(conn, params) do
    username = params["username"]
    opts = Keyword.put(parse_pagination_params(params), :version, :v1)

    case Stardance.DB.list_user_projects(username, opts) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end
end
