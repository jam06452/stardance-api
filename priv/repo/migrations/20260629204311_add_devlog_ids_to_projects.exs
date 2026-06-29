defmodule Stardance.Repo.Migrations.AddDevlogIdsToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :devlog_ids, {:array, :integer}, default: []
    end
  end
end
