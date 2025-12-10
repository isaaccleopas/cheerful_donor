defmodule CheerfulDonor.Paystack do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Paystack.WebhookEvent
  end
end
