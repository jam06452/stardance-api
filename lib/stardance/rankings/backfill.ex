defmodule Stardance.Rankings.Backfill do
  @moduledoc """
  One-shot GenServer that backfills missing devlog and project scores
  on application startup, then exits normally.
  """

  use GenServer, restart: :temporary

  require Logger
  alias Stardance.Repo
  alias Stardance.Rankings
  alias Stardance.Schema.{Devlog, Project}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    backfill_devlog_scores()
    backfill_project_scores()
    {:ok, nil, {:continue, :done}}
  end

  @impl true
  def handle_continue(:done, state) do
    {:stop, :normal, state}
  end

  defp backfill_devlog_scores do
    import Ecto.Query

    devlogs =
      Repo.all(
        from(d in Devlog,
          where: is_nil(d.score) or d.score == 0.0
        )
      )

    if devlogs != [] do
      Logger.info("Rankings.Backfill: Backfilling #{length(devlogs)} devlog scores ...")
    end

    Enum.each(devlogs, fn devlog ->
      score = Rankings.devlog_score(devlog)

      devlog
      |> Devlog.changeset(%{score: score})
      |> Repo.update!()
    end)
  end

  defp backfill_project_scores do
    import Ecto.Query

    projects =
      Repo.all(
        from(p in Project,
          where: is_nil(p.score) or p.score == 0.0
        )
      )

    if projects != [] do
      Logger.info("Rankings.Backfill: Backfilling #{length(projects)} project scores ...")
    end

    Enum.each(projects, fn project ->
      Rankings.update_project_score(project.id)
    end)
  end
end
