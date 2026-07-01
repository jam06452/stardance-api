defmodule Stardance.Schema.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "comments" do
    field :author_username, :string
    field :body, :string
    field :scraped_at, :utc_datetime

    belongs_to :devlog, Stardance.Schema.Devlog, type: :integer
    belongs_to :user, Stardance.Schema.User, type: :binary_id

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :id,
      :author_username,
      :body,
      :scraped_at,
      :devlog_id,
      :user_id
    ])
    |> validate_required([:author_username, :body, :devlog_id, :scraped_at])
    |> foreign_key_constraint(:devlog_id)
    |> foreign_key_constraint(:user_id)
  end
end
