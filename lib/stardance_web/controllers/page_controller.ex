defmodule StardanceWeb.PageController do
  use StardanceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
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
