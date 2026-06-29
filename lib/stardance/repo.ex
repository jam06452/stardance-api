defmodule Stardance.Repo do
  use Ecto.Repo,
    otp_app: :stardance,
    adapter: Ecto.Adapters.Postgres
end
