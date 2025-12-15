defmodule CheerfulDonorWeb.PaystackWebhookController do
  use CheerfulDonorWeb, :controller

  def handle(conn, _params) do
    raw_body = conn.assigns[:raw_body] || ""

    received_sig =
      conn
      |> get_req_header("x-paystack-signature")
      |> List.first()

    secret = paystack_secret_key()

    expected_sig =
      :crypto.mac(:hmac, :sha512, secret, raw_body)
      |> Base.encode16(case: :lower)

    if received_sig != expected_sig do
      send_resp(conn, 401, "invalid signature")
    else
      payload = Jason.decode!(raw_body)

      Task.start(fn ->
        case save_webhook_event(payload) do
          {:ok, webhook_event} ->
            result = CheerfulDonor.Payments.HandlePaystackEvent.process(payload)

            IO.inspect(webhook_event, label: "Saved Webhook Event")
            if result != :ignored do
              IO.inspect(result, label: "Processing Result")
              Ash.Changeset.for_update(webhook_event, :mark_processed, %{processed: true})
              |> Ash.update!()
            end

          _ ->
            CheerfulDonor.Payments.HandlePaystackEvent.process(payload)
        end
      end)

      send_resp(conn, 200, "ok")
    end
  end

  defp save_webhook_event(%{"event" => event} = payload) do
    case CheerfulDonor.Enums.map_event_type(event) do
      nil ->
        {:ignored, nil}

      event_type ->
        CheerfulDonor.Paystack.WebhookEvent
        |> Ash.Changeset.for_create(:create, %{
          event_type: event_type,
          payload: payload
        })
        |> Ash.create()
    end
  end

  defp paystack_secret_key do
    case Application.get_env(:cheerful_donor, :env, :dev) do
      :prod -> System.fetch_env!("PAYSTACK_SECRET_KEY")
      _ -> System.fetch_env!("PAYSTACK_TEST_SECRET_KEY")
    end
  end
end
