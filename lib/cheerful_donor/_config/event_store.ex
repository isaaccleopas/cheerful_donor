defmodule CheerfulDonor.EventStore do
  use EventStore, otp_app: :cheerful_donor

  def init(config), do: {:ok, config}
end
