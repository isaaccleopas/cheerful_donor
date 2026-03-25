defmodule CheerfulDonor.Paystack.Client do
  require Logger

  @paystack_url "https://api.paystack.co"

  # Load secret keys based on env
  env = Application.compile_env(:cheerful_donor, :env, :dev)

  case env do
    :prod -> @secret_key System.get_env("PAYSTACK_SECRET_KEY")
    _ -> @secret_key System.get_env("PAYSTACK_TEST_SECRET_KEY")
  end

  @http_headers [
    {"Content-Type", "application/json"},
    {"Authorization", "Bearer #{@secret_key}"}
  ]

  @http_options [
    timeout: 8_000,         # 8 seconds connection timeout
    recv_timeout: 10_000    # 10 seconds read timeout
  ]

  # -------------------------
  # Unified Request Handler
  # -------------------------
  defp request(method, url, body \\ nil, headers \\ []) do
    headers = headers ++ @http_headers

    response =
      case method do
        :get -> HTTPoison.get(url, headers, @http_options)
        :post -> HTTPoison.post(url, body, headers, @http_options)
      end

    case response do
      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        parse_response(code, body)

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Paystack request error: #{inspect(reason)}")
        {:error, %{error: :network_error, reason: reason}}

      unexpected ->
        Logger.error("Unexpected Paystack request response: #{inspect(unexpected)}")
        {:error, %{error: :unexpected_response, response: unexpected}}
    end
  end

  # -------------------------
  # Safe JSON Parser
  # -------------------------
  defp parse_response(code, body) do
    case Jason.decode(body) do
      {:ok, decoded} ->
        if code in 200..299 do
          {:ok, decoded}
        else
          {:error, %{status_code: code, response: decoded}}
        end

      {:error, _} ->
        Logger.error("""
        Failed to decode Paystack JSON response:
        #{inspect(body)}
        """)

        {:error, %{status_code: code, response: :invalid_json}}
    end
  end

  # -------------------------
  # Initialize Transaction
  # -------------------------
  def initialize_transaction(params) do
    url = "#{@paystack_url}/transaction/initialize"

    # Add idempotency key to avoid duplicate charges when users click twice
    idempotency_key = params["reference"] || params[:reference] || UUID.uuid4()

    headers = [
      {"Idempotency-Key", idempotency_key}
    ]

    body = Jason.encode!(params)
    request(:post, url, body, headers)
  end

  # -------------------------
  # Verify a completed transaction
  # -------------------------
  def verify_transaction(reference) do
    url = "#{@paystack_url}/transaction/verify/#{reference}"
    request(:get, url)
  end

  # -------------------------
  # Charge saved card authorization (recurring)
  # -------------------------
  def charge_authorization(auth_code, email, amount) do
    url = "#{@paystack_url}/transaction/charge_authorization"

    body =
      Jason.encode!(%{
        "authorization_code" => auth_code,
        "email" => email,
        "amount" => amount
      })

    # Prevent duplicate subscription billing charges
    headers = [
      {"Idempotency-Key", "charge-" <> auth_code <> "-" <> to_string(amount)}
    ]

    request(:post, url, body, headers)
  end

  @doc """
  Create a subscription for a customer on Paystack.
  Params must include:
    - :customer_code (string)
    - :plan_code (string)
    - :authorization (string, optional for new customer card)
  """
  def create_subscription(%{customer_code: customer, plan_code: plan_code} = params) do
    url = "#{@paystack_url}/subscription"

    body =
      %{
        customer: customer,
        plan: plan_code   # 🔥 THIS IS THE FIX
      }
      |> then(fn map ->
        case Map.get(params, :authorization) do
          nil -> map
          auth -> Map.put(map, :authorization, auth)
        end
      end)
      |> Jason.encode!()

    request(:post, url, body)
  end

  def create_plan(name, amount, interval) do
    url = "#{@paystack_url}/plan"

    body =
      Jason.encode!(%{
        name: name,
        amount: amount * 100,
        interval: to_string(interval)
      })

    request(:post, url, body)
  end

  def disable_subscription(subscription_code, email_token) do
    url = "#{@paystack_url}/subscription/disable"

    body =
      Jason.encode!(%{
        code: subscription_code,
        token: email_token
      })

    request(:post, url, body)
  end

  @doc """
  Create a new customer on Paystack.
  Expects a map with :email, :first_name, :last_name, :phone keys.
  """
  def create_customer(params) do
    required_keys = [:email, :first_name, :last_name, :phone]

    if Enum.all?(required_keys, &Map.has_key?(params, &1)) do
      url = "#{@paystack_url}/customer"
      body = Jason.encode!(params)
      request(:post, url, body)
    else
      {:error, %{error: :missing_required_params}}
    end
  end

  def create_transfer_recipient(params) do
    url = "#{@paystack_url}/transferrecipient"

    body =
      Jason.encode!(%{
        type: "nuban",
        name: params["account_name"],
        account_number: params["account_number"],
        bank_code: params["bank_code"],
        currency: "NGN"
      })

    request(:post, url, body)
  end

  def initiate_transfer(recipient_code, amount, reference) do
    url = "#{@paystack_url}/transfer"

    body =
      Jason.encode!(%{
        source: "balance",
        amount: amount * 100,
        recipient: recipient_code,
        reference: reference,
        reason: "Church donation payout"
      })

    request(:post, url, body)
  end

  def get_balance do
    url = "#{@paystack_url}/balance"

    case request(:get, url) do
      {:ok, %{"data" => balances}} ->
        ngn_balance =
          balances
          |> Enum.find(&(&1["currency"] == "NGN"))
          |> Map.get("balance", 0)

        {:ok, div(ngn_balance, 100)}

      {:error, error} ->
        {:error, error}
    end
  end
end
