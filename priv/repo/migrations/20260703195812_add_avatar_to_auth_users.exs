defmodule Stardance.Repo.Migrations.AddAvatarToAuthUsers do
  use Ecto.Migration

  def change do
    alter table(:auth_users) do
      add :avatar, :string
    end

    create unique_index(:auth_users, [:slack_id])
  end
end
