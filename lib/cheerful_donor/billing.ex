defmodule CheerfulDonor.Billing do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Billing.PaymentMethod
    resource CheerfulDonor.Billing.Subscription
  end
end
