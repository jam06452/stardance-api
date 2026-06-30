defmodule Stardance.Repo.Migrations.AddLastScrapedAtToRecords do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :last_scraped_at, :utc_datetime
    end

    alter table(:projects) do
      add :last_scraped_at, :utc_datetime
    end

    alter table(:devlogs) do
      add :last_scraped_at, :utc_datetime
    end
  end
end
