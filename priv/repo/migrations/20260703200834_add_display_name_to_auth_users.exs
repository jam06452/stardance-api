defmodule Stardance.Repo.Migrations.AddDisplayNameToAuthUsers do
  use Ecto.Migration

  def change do
    alter table(:auth_users) do
      add :display_name, :string
    end
  end
end
