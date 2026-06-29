defmodule StardanceWeb.PageController do
  use StardanceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
