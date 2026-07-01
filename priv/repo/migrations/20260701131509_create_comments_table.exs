defmodule Stardance.Repo.Migrations.CreateCommentsTable do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :devlog_id, references(:devlogs, on_delete: :delete_all), null: false
      add :author_username, :string, null: false
      add :body, :text, null: false
      add :scraped_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:comments, [:devlog_id])
    create index(:comments, [:author_username])
  end
end
