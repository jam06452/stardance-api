defmodule Stardance.Rankings do
  import Ecto.Query
  alias Stardance.Repo
  alias Stardance.Schema.{Devlog, Project}

  # Devlog weights
  @like_weight 2.0
  @comment_weight 5.0
  @view_weight 1.1
  @word_count_weight 1.0

  # Project weights
  @hour_weight 1.1
  @demo_weight 1.1
  @source_weight 1.1
  @superstar_weight 1.3
  @follower_weight 1.5

  def devlog_score(likes, comments, views, word_count) do
    @like_weight * likes +
      @comment_weight * comments +
      @view_weight * :math.log10(views + 1) +
      @word_count_weight * :math.log10(word_count + 1)
  end

  def devlog_score(%Devlog{} = devlog) do
    likes = devlog.likes || 0
    comments = devlog.comments_count || 0
    views = devlog.views || 0
    word_count = word_count(devlog.description)

    devlog_score(likes, comments, views, word_count)
  end

  def project_score(total_hours, devlog_scores, has_demo?, has_source?, superstar?, followers) do
    demo_weight = if has_demo?, do: @demo_weight, else: 1.0
    source_weight = if has_source?, do: @source_weight, else: 1.0
    superstar_weight = if superstar?, do: @superstar_weight, else: 1.0
    follower_multiplier = @follower_weight * :math.log10(followers + 1)

    devlogs_sum = Enum.sum(devlog_scores)
    hours_component = @hour_weight * :math.log2(total_hours + 1)

    (hours_component + devlogs_sum) * demo_weight * source_weight * superstar_weight *
      follower_multiplier
  end

  def project_score(%Project{} = project) do
    total_hours = project.total_hours || 0.0
    has_demo? = not is_nil(project.demo_url) and project.demo_url != ""
    has_source? = not is_nil(project.source_code) and project.source_code != ""
    superstar? = project.super_star || false
    followers = project.followers || 0

    devlog_scores =
      if Ecto.assoc_loaded?(project.devlogs) do
        Enum.map(project.devlogs, &devlog_score/1)
      else
        Repo.all(from(d in Devlog, where: d.project_id == ^project.id, select: d.score))
        |> Enum.map(&(&1 || 0.0))
      end

    project_score(total_hours, devlog_scores, has_demo?, has_source?, superstar?, followers)
  end

  def update_devlog_score(%Devlog{} = devlog) do
    score = devlog_score(devlog)

    devlog
    |> Devlog.changeset(%{score: score})
    |> Repo.update!()
    |> then(fn updated_devlog ->
      update_project_score(devlog.project_id)
      updated_devlog
    end)
  end

  def update_project_score(project_id) do
    project = Repo.get!(Project, project_id) |> Repo.preload(:devlogs)
    score = project_score(project)

    project
    |> Project.changeset(%{score: score})
    |> Repo.update!()
  end

  def score_devlog_attrs(attrs) when is_map(attrs) do
    likes = get_attr(attrs, :likes, 0)
    comments = get_attr(attrs, :comments_count, 0)
    views = get_attr(attrs, :views, 0)
    description = get_attr(attrs, :description, "") || ""
    word_count = word_count(description)

    score = devlog_score(likes, comments, views, word_count)
    Map.put(attrs, :score, score)
  end

  def score_project_attrs(attrs) when is_map(attrs) do
    project_id = get_attr(attrs, :id, nil)
    total_hours = get_attr(attrs, :total_hours, 0.0)

    demo = get_attr(attrs, :demo_url, nil)
    has_demo? = not is_nil(demo) and demo != ""

    source = get_attr(attrs, :source_code, nil)
    has_source? = not is_nil(source) and source != ""

    superstar = get_attr(attrs, :super_star, false)
    superstar? = if is_boolean(superstar), do: superstar, else: false

    devlog_scores =
      if is_integer(project_id) do
        Repo.all(from(d in Devlog, where: d.project_id == ^project_id, select: d.score))
        |> Enum.map(&(&1 || 0.0))
      else
        []
      end

    followers = get_attr(attrs, :followers, 0)

    score =
      project_score(total_hours, devlog_scores, has_demo?, has_source?, superstar?, followers)

    Map.put(attrs, :score, score)
  end

  defp get_attr(attrs, key, default) when is_atom(key) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, Atom.to_string(key), default)
    end
  end

  defp word_count(nil), do: 0
  defp word_count(description) when is_binary(description), do: length(String.split(description))
end
