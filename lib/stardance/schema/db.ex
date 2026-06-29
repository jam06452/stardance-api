defmodule Stardance.DB do
  import Ecto.Query
  require Logger

  alias Stardance.Schema.{User, Project, Devlog}
  alias Stardance.Repo

  def get_user(username) do
    username = String.trim_leading(username, "@")

    case Repo.get_by(User, username: username) do
      %User{} = user -> {:ok, normalize_user(user)}
      nil -> fetch_and_store_user(username)
    end
  end

  def get_project(id) do
    case Repo.get(Project, id) |> Repo.preload([:user, :devlogs]) do
      %Project{} = project ->
        {:ok, normalize_project(project)}

      nil ->
        fetch_and_store_project(id)
    end
  end

  def get_devlog_by_id(id) do
    case Repo.get(Devlog, id) do
      %Devlog{} = devlog -> {:ok, normalize_devlog(devlog)}
      nil -> {:error, :not_found}
    end
  end

  def write_record(:user, attrs), do: insert_record(User, attrs)
  def write_record(:project, attrs), do: insert_record(Project, attrs)
  def write_record(:devlog, attrs), do: insert_record(Devlog, attrs)

  def write_record(schema, attrs) when is_binary(schema) do
    write_record(String.to_existing_atom(schema), attrs)
  rescue
    ArgumentError -> {:error, "Unknown table or schema: #{inspect(schema)}"}
  end

  def write_record(unknown_table, _attrs) do
    {:error, "Unknown table or schema: #{inspect(unknown_table)}"}
  end

  defp fetch_and_store_user(username) do
    with {:ok, data} <- Stardance.Utils.get_user(username),
         {:ok, saved_user} <- write_record(:user, data) do
      # Best-effort cascade: scrape and store each project referenced by the user.
      _ = scrape_and_store_projects(data.project_ids, saved_user.id)

      {:ok, normalize_user(saved_user)}
    end
  end

  defp scrape_and_store_projects(project_ids, user_id) when is_list(project_ids) do
    Task.async_stream(
      project_ids,
      fn project_id ->
        with {:ok, data} <- Stardance.Utils.get_project(project_id),
             data_with_user = Map.put(data, :user_id, user_id),
             {:ok, _project} <- write_record(:project, data_with_user) do
          scrape_and_store_devlogs(project_id, data.devlog_ids, user_id)
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp scrape_and_store_projects(_project_ids, _user_id), do: :ok

  defp fetch_and_store_project(id) do
    with {:ok, data} <- Stardance.Utils.get_project(id),
         user_id when not is_nil(user_id) <- get_user_id(data.username),
         data_with_user = Map.put(data, :user_id, user_id),
         {:ok, project} <- write_record(:project, data_with_user) do
      # Best-effort cascade: scrape and store each devlog referenced by the project.
      _ = scrape_and_store_devlogs(id, data.devlog_ids, user_id)

      project_with_assoc = %{project | user: %User{username: data.username}}
      {:ok, normalize_project(project_with_assoc)}
    else
      nil -> {:error, :user_id_resolution_failed}
      {:error, reason} -> {:error, reason}
    end
  end

  defp scrape_and_store_devlogs(project_id, devlog_ids, user_id) when is_list(devlog_ids) do
    Task.async_stream(
      devlog_ids,
      fn devlog_id ->
        with {:ok, data} <- Stardance.Utils.get_devlog(project_id, devlog_id),
             data_with_user = Map.put(data, :user_id, user_id) do
          write_record(:devlog, data_with_user)
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

  defp insert_record(schema_module, attrs) do
    result =
      struct(schema_module)
      |> schema_module.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing, conflict_target: :id)

    case result do
      {:error, changeset} ->
        Logger.error("#{inspect(schema_module)} Insert Failed: #{inspect(changeset.errors)}")
        {:error, changeset}

      {:ok, record} ->
        {:ok, record}
    end
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
