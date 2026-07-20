defmodule CheerfulDonor.Giving.Lookups.DonationTest do
  use CheerfulDonor.DataCase, async: false

  alias CheerfulDonor.Giving.Lookups.Donation
  alias CheerfulDonor.Giving.InitiateDonation.DonationInitiatedV1
  alias CheerfulDonor.Giving.ConfirmDonation.DonationConfirmedV1
  alias CheerfulDonor.Giving.FailDonation.DonationFailedV1
  alias CheerfulDonor.Accounts.{User, Church}
  alias CheerfulDonor.Giving.Campaign

  setup do
    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "admin-es-#{System.unique_integer([:positive])}@example.com",
        password: "Password123!",
        password_confirmation: "Password123!",
        role: :admin
      })
      |> Ash.create(authorize?: false)

    {:ok, church} =
      Church
      |> Ash.Changeset.for_create(:create, %{
        name: "Test Church",
        email: "church@example.com",
        user_id: user.id
      })
      |> Ash.create(authorize?: false)

    {:ok, campaign} =
      Campaign
      |> Ash.Changeset.for_create(:create, %{
        title: "Building Fund",
        slug: "building-#{System.unique_integer([:positive])}",
        description: "Help us build",
        church_id: church.id,
        is_active: true
      })
      |> Ash.create(authorize?: false)

    %{church: church, campaign: campaign}
  end

  test "DonationInitiatedV1 upserts pending lookup", %{church: church, campaign: campaign} do
    reference = Ecto.UUID.generate()

    assert :ok =
             Donation.handle(
               %DonationInitiatedV1{
                 reference: reference,
                 amount: 5000,
                 currency: "NGN",
                 donor_id: nil,
                 campaign_id: campaign.id,
                 church_id: church.id,
                 guest_email: "guest@example.com",
                 guest_name: "Guest",
                 type: "one_time",
                 interval: nil,
                 initiated_at: DateTime.utc_now() |> DateTime.to_iso8601()
               },
               %{}
             )

    assert {:ok, lookup} = Ash.get(Donation, reference, authorize?: false)
    assert lookup.status == "pending"
    assert lookup.amount == 5000
    assert lookup.guest_email == "guest@example.com"
  end

  test "DonationFailedV1 marks lookup failed", %{church: church, campaign: campaign} do
    reference = Ecto.UUID.generate()

    :ok =
      Donation.handle(
        %DonationInitiatedV1{
          reference: reference,
          amount: 1000,
          currency: "NGN",
          donor_id: nil,
          campaign_id: campaign.id,
          church_id: church.id,
          guest_email: nil,
          guest_name: nil,
          type: "one_time",
          interval: nil,
          initiated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        },
        %{}
      )

    assert :ok =
             Donation.handle(
               %DonationFailedV1{
                 reference: reference,
                 reason: "declined",
                 failed_at: DateTime.utc_now() |> DateTime.to_iso8601()
               },
               %{}
             )

    assert {:ok, lookup} = Ash.get(Donation, reference, authorize?: false)
    assert lookup.status == "failed"
  end

  test "DonationConfirmedV1 creates donation and updates campaign stats", %{
    church: church,
    campaign: campaign
  } do
    reference = Ecto.UUID.generate()

    :ok =
      Donation.handle(
        %DonationInitiatedV1{
          reference: reference,
          amount: 7500,
          currency: "NGN",
          donor_id: nil,
          campaign_id: campaign.id,
          church_id: church.id,
          guest_email: "guest@example.com",
          guest_name: "Guest",
          type: "one_time",
          interval: nil,
          initiated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        },
        %{}
      )

    assert :ok =
             Donation.handle(
               %DonationConfirmedV1{
                 reference: reference,
                 amount: 7500,
                 paid_at: DateTime.utc_now() |> DateTime.to_iso8601(),
                 channel: "card",
                 customer_code: nil,
                 authorization_code: nil,
                 raw: %{}
               },
               %{}
             )

    assert {:ok, lookup} = Ash.get(Donation, reference, authorize?: false)
    assert lookup.status == "successful"

    stats = CheerfulDonor.Giving.campaign_stats(campaign.id)
    assert stats.raised >= 7500
    assert stats.donor_count >= 1
  end
end
