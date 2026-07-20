defmodule CheerfulDonor.Giving.Workers.VerifyPendingDonationsTest do
  use CheerfulDonor.DataCase, async: false

  alias CheerfulDonor.Giving
  alias CheerfulDonor.Giving.Lookups.Donation
  alias CheerfulDonor.Giving.InitiateDonation.DonationInitiatedV1
  alias CheerfulDonor.Accounts.{User, Church}
  alias CheerfulDonor.Giving.Campaign

  setup do
    {:ok, user} =
      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: "verify-job-#{System.unique_integer([:positive])}@example.com",
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

  test "list_pending_donations_for_verification skips recent pending rows", %{
    church: church,
    campaign: campaign
  } do
    reference = Ecto.UUID.generate()

    :ok =
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

    assert Giving.list_pending_donations_for_verification(grace_minutes: 2) == []
  end

  test "verify_pending_donation returns already_confirmed for successful lookup", %{
    church: church,
    campaign: campaign
  } do
    reference = Ecto.UUID.generate()

    :ok =
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

    Donation
    |> Ash.Changeset.for_create(:upsert, %{
      reference: reference,
      status: "successful",
      amount: 5000
    })
    |> Ash.create!(authorize?: false)

    assert :already_confirmed = Giving.verify_pending_donation(reference)
  end
end
