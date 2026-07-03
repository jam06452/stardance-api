defmodule Stardance.Accounts do
  import Ecto.Query

  alias Stardance.Repo
  alias Stardance.Schema.AuthUser

  def get_user!(id), do: Repo.get!(AuthUser, id)

  def update_auth_user(%AuthUser{} = user, attrs) do
    user
    |> AuthUser.changeset(attrs)
    |> Repo.update()
  end

  def list_endorsed_users do
    Repo.all(
      from u in AuthUser,
        where: u.endorsed == true,
        order_by: [desc: u.inserted_at]
    )
  end
end
