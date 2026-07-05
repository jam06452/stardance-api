defmodule Stardance.Schema.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "users" do
    field :username, :string
    field :user_pfp, :string
    field :bio, :string
    field :banner_url, :string
    field :devlog_count, :integer, default: 0
    field :project_count, :integer, default: 0
    field :project_ids, {:array, :integer}, default: []
    field :devlog_ids, {:array, :integer}, default: []
    field :ships, :integer, default: 0
    field :votes, :integer, default: 0
    field :slack_id, :string
    field :stardust, :integer
    field :like_count, :integer, default: 0
    field :vote_count, :integer, default: 0
    field :slack_url, :string
    field :last_scraped_at, :utc_datetime

    has_many :projects, Stardance.Schema.Project
    has_many :devlogs, Stardance.Schema.Devlog
    has_many :achievements, Stardance.Schema.Achievement

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :id,
      :username,
      :user_pfp,
      :bio,
      :banner_url,
      :devlog_count,
      :project_count,
      :project_ids,
      :devlog_ids,
      :ships,
      :votes,
      :slack_id,
      :stardust,
      :like_count,
      :vote_count,
      :slack_url,
      :last_scraped_at
    ])
    |> validate_required([:username])
    |> unique_constraint(:username)
  end
end
