defmodule Stardance.Repo.Migrations.AddProjectFields do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :repo_url, :string
      add :readme_url, :string
      add :ai_declaration, :string
      add :ship_status, :string
    end

    alter table(:devlogs) do
      add :scrapbook_url, :string
    end

    alter table(:users) do
      add :slack_id, :string
      add :stardust, :integer
      add :like_count, :integer, default: 0
      add :vote_count, :integer, default: 0
    end

    create table(:achievements) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :description, :string
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:achievements, [:user_id])
    create unique_index(:achievements, [:user_id, :slug])
  end
end
