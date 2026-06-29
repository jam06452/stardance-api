defmodule Stardance.Schema.Devlog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "devlogs" do
    field :description, :string
    field :image_urls, {:array, :string}, default: []
    field :likes, :integer, default: 0
    field :views, :integer, default: 0

    belongs_to :user, Stardance.Schema.User, type: :binary_id
    belongs_to :project, Stardance.Schema.Project

    timestamps()
  end

  def changeset(devlog, attrs) do
    devlog
    |> cast(attrs, [
      :description,
      :image_urls,
      :likes,
      :views,
      :user_id,
      :project_id
    ])
    |> validate_required([:description, :user_id, :project_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:project_id)
  end
end
