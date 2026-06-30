defmodule Stardance.DB do
  import Ecto.Query
  require Logger

  alias Stardance.Schema.{User, Project, Devlog}
  alias Stardance.Repo

  @stale_hours 12
  @stale_seconds @stale_hours * 60 * 60

  def stale?(nil), do: true
  def stale?(%{last_scraped_at: nil}), do: true

  def stale?(%{last_scraped_at: ts}) do
    DateTime.diff(DateTime.utc_now(), ts, :second) > @stale_seconds
  end

  # Public API

  def get_user(username) do
    username = String.trim_leading(username, "@")

    case Repo.get_by(User, username: username) do
      nil ->
        fetch_and_store_user(username)

      user ->
        if stale?(user) do
          with {:ok, scraped_user} <- refresh_user(username) do
            run_background(fn ->
              scrape_and_store_projects(scraped_user.project_ids, scraped_user.id)
            end)

            {:ok, normalize_user(scraped_user)}
          end
        else
          {:ok, normalize_user(user)}
        end
    end
  end

  def get_project(id) do
    case Repo.get(Project, id) |> Repo.preload([:user, :devlogs]) do
      nil ->
        fetch_and_store_project(id)

      project ->
        if stale?(project) do
          with {:ok, scraped_project} <- refresh_project(id) do
            run_background(fn ->
              scrape_and_store_devlogs(id, scraped_project.devlog_ids, scraped_project.user_id)
            end)

            {:ok, normalize_project(scraped_project)}
          end
        else
          {:ok, normalize_project(project)}
        end
    end
  end

  def get_devlog_by_id(id) do
    case Repo.get(Devlog, id) do
      nil ->
        {:error, :not_found}

      devlog ->
        if stale?(devlog) do
          with {:ok, refreshed_devlog} <- refresh_devlog(devlog.project_id, id) do
            {:ok, normalize_devlog(refreshed_devlog)}
          end
        else
          {:ok, normalize_devlog(devlog)}
        end
    end
  end

  def get_project_devlog(project_id, devlog_id) do
    case Repo.get_by(Devlog, id: devlog_id, project_id: project_id) do
      nil ->
        fetch_and_store_devlog(project_id, devlog_id)

      devlog ->
        if stale?(devlog) do
          with {:ok, refreshed_devlog} <- refresh_devlog(project_id, devlog_id) do
            {:ok, normalize_devlog(refreshed_devlog)}
          end
        else
          {:ok, normalize_devlog(devlog)}
        end
    end
  end

  def write_record(:user, attrs), do: upsert_record(User, attrs)
  def write_record(:project, attrs), do: upsert_record(Project, attrs)
  def write_record(:devlog, attrs), do: upsert_record(Devlog, attrs)

  def write_record(schema, attrs) when is_binary(schema) do
    write_record(String.to_existing_atom(schema), attrs)
  rescue
    ArgumentError -> {:error, "Unknown table or schema: #{inspect(schema)}"}
  end

  def write_record(unknown_table, _attrs) do
    {:error, "Unknown table or schema: #{inspect(unknown_table)}"}
  end

  # Private helpers

  defp refresh_user(username) do
    with {:ok, data} <- Stardance.Utils.get_user(username),
         data = put_timestamp(data),
         {:ok, saved_user} <- upsert_record(User, data) do
      {:ok, saved_user}
    end
  end

  defp fetch_and_store_user(username) do
    with {:ok, user} <- refresh_user(username) do
      run_background(fn -> scrape_and_store_projects(user.project_ids, user.id) end)
      {:ok, normalize_user(user)}
    end
  end

  defp refresh_project(id) do
    with {:ok, data} <- Stardance.Utils.get_project(id),
         user_id when not is_nil(user_id) <- get_user_id(data.username),
         data = data |> Map.put(:user_id, user_id) |> put_timestamp(),
         {:ok, project} <- upsert_record(Project, data) do
      {:ok, Repo.preload(project, :user)}
    else
      nil -> {:error, :user_id_resolution_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_and_store_project(id) do
    with {:ok, project} <- refresh_project(id) do
      run_background(fn ->
        scrape_and_store_devlogs(id, project.devlog_ids, project.user_id)
      end)

      {:ok, normalize_project(project)}
    end
  end

  defp refresh_devlog(project_id, devlog_id) do
    with {:ok, data} <- Stardance.Utils.get_devlog(project_id, devlog_id),
         user_id when not is_nil(user_id) <- get_user_id(data.username),
         data = data |> Map.put(:user_id, user_id) |> put_timestamp(),
         {:ok, devlog} <- upsert_record(Devlog, data) do
      {:ok, devlog}
    else
      nil -> {:error, :user_id_resolution_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_and_store_devlog(project_id, devlog_id) do
    with {:ok, devlog} <- refresh_devlog(project_id, devlog_id) do
      {:ok, normalize_devlog(devlog)}
    end
  end

  defp scrape_and_store_projects(project_ids, _user_id) when is_list(project_ids) do
    Task.async_stream(
      project_ids,
      fn project_id ->
        with {:ok, data} <- Stardance.Utils.get_project(project_id),
             user_id when not is_nil(user_id) <- get_user_id(data.username),
             data = data |> Map.put(:user_id, user_id) |> put_timestamp(),
             {:ok, _project} <- upsert_record(Project, data) do
          scrape_and_store_devlogs(project_id, data.devlog_ids, user_id)
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp scrape_and_store_projects(_project_ids, _user_id), do: :ok

  defp scrape_and_store_devlogs(project_id, devlog_ids, _user_id) when is_list(devlog_ids) do
    Task.async_stream(
      devlog_ids,
      fn devlog_id ->
        with {:ok, data} <- Stardance.Utils.get_devlog(project_id, devlog_id),
             user_id when not is_nil(user_id) <- get_user_id(data.username),
             data = data |> Map.put(:user_id, user_id) |> put_timestamp() do
          upsert_record(Devlog, data)
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp scrape_and_store_devlogs(_project_id, _devlog_ids, _user_id), do: :ok

  defp get_user_id(nil), do: nil

  defp get_user_id(username) do
    username = String.trim_leading(username, "@")

    case Repo.one(from u in User, where: u.username == ^username, select: u.id) do
      nil ->
        case get_user(username) do
          {:ok, user} -> user.user_id
          {:error, _} -> nil
        end

      id ->
        id
    end
  end

  defp upsert_record(User, attrs) do
    struct(User)
    |> User.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace_all_except, [:id]},
      conflict_target: :username,
      returning: true
    )
  end

  defp upsert_record(schema_module, attrs) do
    schema_module
    |> struct()
    |> schema_module.changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: :id,
      returning: true
    )
  end

  defp put_timestamp(attrs) do
    Map.put(attrs, :last_scraped_at, DateTime.utc_now())
  end

  defp run_background(fun) do
    Task.Supervisor.start_child(Stardance.ScrapeSupervisor, fun)
  end

  defp normalize_user(data) do
    %{
      user_id: data.id,
      username: data.username,
      devlog_count: length(data.devlog_ids || []),
      banner_url: data.banner_url,
      user_pfp: data.user_pfp,
      bio: data.bio || "Add a bio to tell folks who you are.",
      project_count: length(data.project_ids || []),
      project_ids: data.project_ids || [],
      devlog_ids: data.devlog_ids || [],
      ships: data.ships || 0,
      votes: data.votes || 0,
      slack_url: data.slack_url
    }
  end

  defp normalize_project(%Project{} = project) do
    devlog_ids =
      cond do
        project.devlog_ids != nil and project.devlog_ids != [] ->
          project.devlog_ids

        Ecto.assoc_loaded?(project.devlogs) ->
          Enum.map(project.devlogs, & &1.id)

        true ->
          []
      end

    %{
      id: project.id,
      description: project.description || "",
      title: project.title,
      username: if(Ecto.assoc_loaded?(project.user), do: project.user.username, else: nil),
      banner_url: project.banner_url,
      devlog_count: project.devlog_count || 0,
      devlog_ids: devlog_ids,
      total_hours: project.total_hours || 0.0,
      followers: project.followers || 0,
      demo_url: project.demo_url,
      sourcecode: project.source_code,
      superstar: project.super_star || false
    }
  end

  defp normalize_devlog(%Devlog{} = devlog) do
    %{
      id: devlog.id,
      description: devlog.description || "",
      image_urls: devlog.image_urls || [],
      likes: devlog.likes || 0,
      views: devlog.views || 0,
      duration_seconds: devlog.duration_seconds || 0,
      project_id: devlog.project_id,
      user_id: devlog.user_id
    }
  end
end
