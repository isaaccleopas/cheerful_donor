defmodule CheerfulDonor.Giving do
  use Ash.Domain,
    otp_app: :cheerful_donor

  resources do
    resource CheerfulDonor.Giving.Campaign
    resource CheerfulDonor.Giving.Donation
    resource CheerfulDonor.Giving.DonationIntent
  end

    # Lookup DonationIntent by reference
  def get_donation_intent(reference) do
    DonationIntent
    |> Ash.Query.filter(reference: reference)
    |> Ash.read_one()
  end

  def update_donation_intent(intent, attrs),
    do: Ash.update(intent, attrs)

  def create_donation(attrs),
    do: Ash.create(Donation, attrs)

  def get_donor_by_subscription(subscription_code) do
    Donor
    |> Ash.Query.filter(subscription_code: subscription_code)
    |> Ash.read_one()
  end
end
