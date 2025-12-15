defmodule CheerfulDonor.Paystack do
  use Ash.Domain,
    otp_app: :cheerful_donor

  alias CheerfulDonor.Paystack.WebhookEvent

  resources do
    resource WebhookEvent
  end

  @doc """
  Create a webhook event record in the database.
  Expects a map with keys: :event_type, :payload, optional :processed.
  """
  def create_webhook_event(attrs) do
    changeset = WebhookEvent |> Ash.Changeset.for_create(:create, attrs)
    Ash.create(changeset)
  end
end
