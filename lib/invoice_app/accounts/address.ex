defmodule InvoiceApp.Accounts.Address do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  embedded_schema do
    field :country, :string
    field :city, :string
    field :street_address, :string
    field :postal_code, :string
    field :phone_number, :string
  end

  @doc false
  def changeset(attrs) do
    changeset(%__MODULE__{}, attrs)
  end

  @doc false
  def changeset(address, attrs) do
    address
    |> cast(attrs, [:country, :city, :street_address, :postal_code, :phone_number])
    |> validate_required([:country, :city, :street_address, :postal_code, :phone_number])
  end
end
