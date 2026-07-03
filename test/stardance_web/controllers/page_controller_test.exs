defmodule StardanceWeb.PageControllerTest do
  use StardanceWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Stardance"
    assert html =~ "Developer API"
  end
end
