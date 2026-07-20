defmodule CheerfulDonorWeb.PageControllerTest do
  use CheerfulDonorWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Cheerful Donor"
  end
end
