defmodule StardanceWeb.PageControllerTest do
  use StardanceWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "api-reference"
    assert html =~ "api-reference.js"
  end
end
