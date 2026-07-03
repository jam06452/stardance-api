defmodule Stardance.Schema.AuthUser do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "auth_users" do
    field :uid, :string
    field :email, :string
    field :name, :string
    field :slack_id, :string
    field :provider, :string
    field :endorsed, :boolean, default: false
    field :avatar, :string

    timestamps()
  end

  def changeset(auth_user, attrs) do
    auth_user
    |> cast(attrs, [:uid, :email, :name, :slack_id, :provider, :endorsed, :avatar])
    |> validate_required([:uid, :provider])
    |> unique_constraint(:uid)
  end
end
