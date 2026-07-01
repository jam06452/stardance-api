defmodule Stardance.Schema.Devlog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "devlogs" do
    field :description, :string
    field :image_urls, {:array, :string}, default: []
    field :likes, :integer, default: 0
    field :views, :integer, default: 0
    field :duration_seconds, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :last_scraped_at, :utc_datetime

    belongs_to :user, Stardance.Schema.User, type: :binary_id
    belongs_to :project, Stardance.Schema.Project
    has_many :comments, Stardance.Schema.Comment

    timestamps()
  end

  def changeset(devlog, attrs) do
    devlog
    |> cast(attrs, [
      :id,
      :description,
      :image_urls,
      :likes,
      :views,
      :duration_seconds,
      :comments_count,
      :user_id,
      :project_id,
      :last_scraped_at
    ])
    |> validate_required([:id, :description, :user_id, :project_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
    |> unique_constraint(:id)
  end
end
