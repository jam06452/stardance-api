defmodule Stardance.Schema.Achievement do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "achievements" do
    field :slug, :string
    field :name, :string
    field :description, :string

    belongs_to :user, Stardance.Schema.User, type: :binary_id

    timestamps()
  end

  def changeset(achievement, attrs) do
    achievement
    |> cast(attrs, [:slug, :name, :description, :user_id])
    |> validate_required([:slug, :name, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  def changeset_by_scrape(achievement_or_nil, attrs, user_id, now) do
    achievement =
      case achievement_or_nil do
        nil -> %__MODULE__{}
        struct -> struct
      end

    achievement
    |> cast(Map.put(attrs, :user_id, user_id), [:slug, :name, :description, :user_id])
    |> put_change(:inserted_at, now)
    |> put_change(:updated_at, now)
    |> validate_required([:slug, :name, :user_id])
  end
end
