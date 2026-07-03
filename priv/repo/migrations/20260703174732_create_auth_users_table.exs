defmodule Stardance.Repo.Migrations.CreateAuthUsersTable do
  use Ecto.Migration

  def change do
    create table(:auth_users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :uid, :string, null: false
      add :email, :string
      add :name, :string
      add :slack_id, :string
      add :provider, :string, null: false
      add :endorsed, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:auth_users, [:uid])
    create index(:auth_users, [:email])
  end
end
