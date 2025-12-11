defmodule CheerfulDonor.Repo.Migrations.AddedModify do
  use Ecto.Migration

  def up do
    # Users table
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name='users' AND column_name='role'
      ) THEN
        ALTER TABLE users ADD COLUMN role text DEFAULT 'donor';
      END IF;
    END$$;
    """)

    # Subscriptions table
    rename table(:subscriptions), :church_id, to: :subscription_code

    execute("""
    DO $$
    BEGIN
      BEGIN
        ALTER TABLE subscriptions DROP CONSTRAINT subscriptions_church_id_fkey;
      EXCEPTION
        WHEN undefined_object THEN
          NULL;
      END;
    END$$;
    """)

    alter table(:subscriptions) do
      modify :subscription_code, :text
      modify :status, :text, default: "pending"
    end

    # Payouts table
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name='payouts' AND column_name='currency'
      ) THEN
        ALTER TABLE payouts ADD COLUMN currency text NOT NULL DEFAULT 'NGN';
      END IF;
    END$$;
    """)

    # Payment methods table
    alter table(:payment_methods) do
      modify :donor_id, :uuid, null: false
      modify :reusable, :boolean, null: false, default: false
    end

    # Donors table
    execute("""
    DO $$
    BEGIN
      BEGIN
        ALTER TABLE donors DROP COLUMN church_id;
      EXCEPTION
        WHEN undefined_column THEN
          NULL;
      END;
    END$$;
    """)

    alter table(:donors) do
      modify :user_id, :uuid, null: false
    end

    # Unique index on donors.user_id
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'donors_unique_user_index'
      ) THEN
        CREATE UNIQUE INDEX donors_unique_user_index ON donors(user_id);
      END IF;
    END$$;
    """)

    # Donation intents table
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name='donation_intents' AND column_name='guest_email'
      ) THEN
        ALTER TABLE donation_intents ADD COLUMN guest_email text;
      END IF;
    END$$;
    """)

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name='donation_intents' AND column_name='guest_name'
      ) THEN
        ALTER TABLE donation_intents ADD COLUMN guest_name text;
      END IF;
    END$$;
    """)

    # Churches table
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name='churches' AND column_name='user_id'
      ) THEN
        ALTER TABLE churches
        ADD COLUMN user_id uuid
        REFERENCES users(id);
      END IF;
    END$$;
    """)
  end

  def down do
    execute("ALTER TABLE users DROP COLUMN IF EXISTS role;")
    rename table(:subscriptions), :subscription_code, to: :church_id

    alter table(:subscriptions) do
      modify :status, :text, default: "active"
      modify :subscription_code,
        references(:churches,
          column: :id,
          name: "subscriptions_church_id_fkey",
          type: :uuid
        )
    end

    execute("ALTER TABLE subscriptions DROP CONSTRAINT IF EXISTS subscriptions_church_id_fkey;")
    execute("ALTER TABLE payouts DROP COLUMN IF EXISTS currency;")

    alter table(:payment_methods) do
      modify :reusable, :boolean, null: true, default: nil
      modify :donor_id, :uuid, null: true
    end

    execute("DROP INDEX IF EXISTS donors_unique_user_index;")
    alter table(:donors) do
      modify :user_id, :uuid, null: true
    end

    execute("""
    DO $$
    BEGIN
      BEGIN
        ALTER TABLE donors ADD COLUMN church_id uuid REFERENCES churches(id);
      EXCEPTION
        WHEN duplicate_column THEN
          NULL;
      END;
    END$$;
    """)

    alter table(:donation_intents) do
      remove :guest_email
      remove :guest_name
    end

    execute("ALTER TABLE churches DROP COLUMN IF EXISTS user_id;")
  end
end
