defmodule StardanceWeb.API.Helpers do
  @moduledoc false

  def send_error(conn, :not_found) do
    conn
    |> Plug.Conn.put_status(:not_found)
    |> Phoenix.Controller.json(%{error: "Resource not found"})
  end

  def send_error(conn, 404) do
    send_error(conn, :not_found)
  end

  def send_error(conn, status) when is_integer(status) do
    conn
    |> Plug.Conn.put_status(status)
    |> Phoenix.Controller.json(%{error: "Request failed with status #{status}"})
  end

  def send_error(conn, reason) do
    conn
    |> Plug.Conn.put_status(:bad_request)
    |> Phoenix.Controller.json(%{error: inspect(reason)})
  end

  def parse_pagination_params(params) do
    opts = []

    opts =
      case Map.get(params, "page") do
        nil -> opts
        val -> Keyword.put(opts, :page, String.to_integer(val))
      end

    opts =
      case Map.get(params, "limit") do
        nil -> opts
        val -> Keyword.put(opts, :limit, min(String.to_integer(val), 100))
      end

    opts =
      case Map.get(params, "query") do
        nil -> opts
        q when is_binary(q) and q != "" -> Keyword.put(opts, :query, q)
        _ -> opts
      end

    opts
  end
end
