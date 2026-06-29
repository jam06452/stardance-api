defmodule MyApp.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :string, null: false
      add :user_pfp, :string
      add :bio, :text
      add :banner_url, :string
      add :devlog_count, :integer, default: 0
      add :project_count, :integer, default: 0
      add :project_ids, {:array, :integer}, default: []
      add :devlog_ids, {:array, :integer}, default: []
      add :ships, :integer, default: 0
      add :votes, :integer, default: 0
      add :slack_url, :string

      timestamps()
    end

    create unique_index(:users, [:username])

    create table(:projects) do
      add :title, :string, null: false
      add :description, :text
      add :devlog_count, :integer, default: 0
      add :total_hours, :float
      add :banner_url, :string
      add :demo_url, :string
      add :source_code, :string
      add :followers, :integer, default: 0
      add :super_star, :boolean, default: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:projects, [:user_id])

    create table(:devlogs) do
      add :description, :text
      add :image_urls, {:array, :string}, default: []
      add :likes, :integer, default: 0
      add :views, :integer, default: 0

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:devlogs, [:user_id])
    create index(:devlogs, [:project_id])
  end
end
