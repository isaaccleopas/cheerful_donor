defmodule CheerfulDonor.CommandedApp do
  use Commanded.Application,
    otp_app: :cheerful_donor,
    event_store: [
      adapter: Commanded.EventStore.Adapters.EventStore,
      event_store: CheerfulDonor.EventStore
    ]

  router(CheerfulDonor.Giving.Shared.Router)
end
