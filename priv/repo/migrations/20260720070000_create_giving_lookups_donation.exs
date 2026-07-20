defmodule CheerfulDonor.Repo.Migrations.CreateGivingLookupsDonation do
  use Ecto.Migration

  def up do
    create table(:giving__lookups__donation, primary_key: false) do
      add :reference, :text, null: false, primary_key: true
      add :amount, :bigint
      add :currency, :text, default: "NGN"
      add :status, :text, null: false, default: "pending"
      add :donor_id, :uuid
      add :campaign_id, :uuid
      add :church_id, :uuid
      add :guest_email, :text
      add :guest_name, :text
      add :type, :text, default: "one_time"
      add :interval, :text
      add :paid_at, :utc_datetime
      add :raw, :map
      add :inserted_at, :utc_datetime
    end

    create unique_index(:giving__lookups__donation, [:reference],
             name: "giving__lookups__donation_unique_reference_index"
           )
  end

  def down do
    drop_if_exists unique_index(:giving__lookups__donation, [:reference],
                     name: "giving__lookups__donation_unique_reference_index"
                   )

    drop table(:giving__lookups__donation)
  end
end
