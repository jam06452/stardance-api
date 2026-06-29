defmodule Stardance.DB do
  alias Stardance.Schema.{User, Project, Devlog}
  alias Stardance.Repo

  def get_user(username) do
    Repo.get!(User, username: username)
  end

  def get_project(id) do
    Repo.get!(Project, id)
  end

  def write_record(:user, attrs), do: insert_record(User, attrs)
  def write_record(:project, attrs), do: insert_record(Project, attrs)
  def write_record(:devlog, attrs), do: insert_record(Devlog, attrs)

  def write_record("user", attrs), do: insert_record(User, attrs)
  def write_record("project", attrs), do: insert_record(Project, attrs)
  def write_record("devlog", attrs), do: insert_record(Devlog, attrs)

  def write_record(unknown_table, _attrs) do
    {:error, "Unknown table or schema: #{inspect(unknown_table)}"}
  end

  defp insert_record(schema_module, attrs) do
    struct(schema_module)
    |> schema_module.changeset(attrs)
    |> Repo.insert()
  end
end
