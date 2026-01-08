defmodule CheerfulDonorWeb.AuthLiveRedirect do
  import Phoenix.LiveView

  alias CheerfulDonor.Accounts

  @impl true
  def redirect_user(conn, user) do
    cond do
      user.role == :admin and no_church?(user) ->
        redirect(conn, to: "/admin/church/new")

      user.role == :admin ->
        redirect(conn, to: "/admin")

      user.role == :donor ->
        redirect(conn, to: "/donor/dashboard")

      true ->
        redirect(conn, to: "/")
    end
  end

  defp no_church?(user) do
    case Accounts.get_church_by_user_id(user.id) do
      {:ok, _church} -> false
      _ -> true
    end
  end
end
