defmodule InvoiceApp.Repo.Migrations.AddNecessaryFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar, :string
      add :name, :string
      add :username, :string, unique: true
      add :address, :map
    end
  end
end
