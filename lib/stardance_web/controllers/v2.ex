defmodule StardanceWeb.API.V2Controller do
  use StardanceWeb, :controller

  import StardanceWeb.API.Helpers, only: [send_error: 2, parse_pagination_params: 1]

  # ── Projects ──────────────────────────────────────────────────────────

  def index(conn, params) do
    opts = Keyword.put(parse_pagination_params(params), :version, :v2)
    {:ok, data} = Stardance.DB.list_projects(opts)
    json(conn, data)
  end

  def projects(conn, %{"id" => id}) do
    case Stardance.DB.get_project(id, version: :v2) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_devlogs(conn, params) do
    project_id = String.to_integer(params["id"])
    opts = Keyword.put(parse_pagination_params(params), :version, :v2)

    case Stardance.DB.list_project_devlogs(project_id, opts) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def project_devlog(conn, %{"id" => project_id, "devlog_id" => devlog_id}) do
    case Stardance.DB.get_project_devlog(project_id, devlog_id, version: :v2) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  # ── Devlogs ───────────────────────────────────────────────────────────

  def devlogs(conn, %{"id" => id}) do
    case Stardance.DB.get_devlog_by_id(id, version: :v2) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def devlogs_index(conn, params) do
    opts = Keyword.put(parse_pagination_params(params), :version, :v2)
    {:ok, data} = Stardance.DB.list_devlogs(opts)
    json(conn, data)
  end

  # ── Users ─────────────────────────────────────────────────────────────

  def list_users(conn, params) do
    opts = Keyword.put(parse_pagination_params(params), :version, :v2)
    {:ok, data} = Stardance.DB.list_users(opts)
    json(conn, data)
  end

  def users(conn, %{"username" => username}) do
    case Stardance.DB.get_user(username, version: :v2) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def user_projects(conn, params) do
    username = params["username"]
    opts = Keyword.put(parse_pagination_params(params), :version, :v2)

    case Stardance.DB.list_user_projects(username, opts) do
      {:ok, data} -> json(conn, data)
      {:error, reason} -> send_error(conn, reason)
    end
  end

  def top_projects(conn, params) do
    opts = params |> parse_pagination_params() |> Keyword.put(:version, :v2)
    {:ok, data} = Stardance.DB.list_top_projects(opts)
    json(conn, data)
  end

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
end
