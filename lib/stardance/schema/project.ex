defmodule Stardance.Schema.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :title, :string
    field :description, :string
    field :devlog_count, :integer, default: 0
    field :total_hours, :float
    field :banner_url, :string
    field :demo_url, :string
    field :source_code, :string
    field :followers, :integer, default: 0
    field :super_star, :boolean, default: false

    belongs_to :user, Stardance.Schema.User, type: :binary_id
    has_many :devlogs, Stardance.Schema.Devlog

    timestamps()
  end

  def changeset(project, attrs) do
    project
    |> cast(attrs, [
      :title,
      :description,
      :devlog_count,
      :total_hours,
      :banner_url,
      :demo_url,
      :source_code,
      :followers,
      :super_star,
      :user_id
    ])
    |> validate_required([:title, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
