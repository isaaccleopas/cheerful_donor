defmodule CheerfulDonor.Giving do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Giving.Campaign
    resource CheerfulDonor.Giving.Donation
    resource CheerfulDonor.Giving.DonationIntent
  end
end
