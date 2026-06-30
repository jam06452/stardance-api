defmodule StardanceWeb.PageController do
  use StardanceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def docs(conn, _params) do
    render(conn, :docs)
  end
end
