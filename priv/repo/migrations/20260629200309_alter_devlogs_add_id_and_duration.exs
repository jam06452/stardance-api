defmodule Stardance.Repo.Migrations.AlterDevlogsAddIdAndDuration do
  use Ecto.Migration

  def up do
    # Replace the auto-increment integer PK with a client-supplied integer PK
    # that mirrors the devlog id from stardance.hackclub.com.
    drop index(:devlogs, [:user_id])
    drop index(:devlogs, [:project_id])

    alter table(:devlogs) do
      remove :id
      add :id, :integer, primary_key: true, null: false
      add :duration_seconds, :integer, default: 0, null: false
    end

    create index(:devlogs, [:user_id])
    create index(:devlogs, [:project_id])
  end

  def down do
    drop index(:devlogs, [:user_id])
    drop index(:devlogs, [:project_id])

    alter table(:devlogs) do
      remove :id
      # :serial automatically implies primary_key and null: false in Postgres
      add :id, :serial, primary_key: true
      remove :duration_seconds
    end

    create index(:devlogs, [:user_id])
    create index(:devlogs, [:project_id])
  end
end
