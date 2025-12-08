defmodule CheerfulDonorWeb.PageController do
  use CheerfulDonorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
