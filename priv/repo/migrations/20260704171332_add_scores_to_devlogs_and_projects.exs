defmodule Stardance.Repo.Migrations.AddScoresToDevlogsAndProjects do
  use Ecto.Migration

  def change do
    alter table(:devlogs) do
      add :score, :float, default: 0.0, null: false
    end

    alter table(:projects) do
      add :score, :float, default: 0.0, null: false
    end
  end
end
