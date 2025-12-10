defmodule CheerfulDonor.Payouts do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Payouts.BankAccount
    resource CheerfulDonor.Payouts.Payout
  end
end
