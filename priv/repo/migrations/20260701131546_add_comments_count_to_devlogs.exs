defmodule Stardance.Repo.Migrations.AddCommentsCountToDevlogs do
  use Ecto.Migration

  def change do
    alter table(:devlogs) do
      add :comments_count, :integer, default: 0, null: false
    end
  end
end
