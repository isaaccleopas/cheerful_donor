defmodule CheerfulDonor.Giving.Workers.VerifyPendingDonations do
  @moduledoc """
  Periodically verifies pending donations with Paystack and confirms successful ones.

  This is a fallback when webhooks are missed (e.g. ngrok downtime). Confirmation
  still requires a successful Paystack verify response — same trust level as webhook data.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias CheerfulDonor.Giving

  @impl Oban.Worker
  def perform(_job) do
    for lookup <- Giving.list_pending_donations_for_verification() do
      case Giving.verify_pending_donation(lookup.reference) do
        :confirmed ->
          Logger.info("Pending donation confirmed via verify job: #{lookup.reference}")

        :already_confirmed ->
          :ok

        :still_pending ->
          :ok

        :failed ->
          Logger.warning("Pending donation marked failed via verify job: #{lookup.reference}")

        other ->
          Logger.warning("Verify job could not confirm #{lookup.reference}: #{inspect(other)}")
      end
    end

    :ok
  end
end
