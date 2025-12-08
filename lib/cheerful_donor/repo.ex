defmodule CheerfulDonor.Repo do
  use Ecto.Repo,
    otp_app: :cheerful_donor,
    adapter: Ecto.Adapters.Postgres
end
