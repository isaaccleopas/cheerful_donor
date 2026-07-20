defmodule CheerfulDonor.Giving.Changes.GenerateSlug do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    title = Ash.Changeset.get_attribute(changeset, :title)

    if is_nil(title) do
      changeset
    else
      slug =
        title
        |> String.downcase()
        |> String.replace(~r/[^a-z0-9\s-]/, "")
        |> String.replace(~r/\s+/, "-")
        |> String.trim("-")

      Ash.Changeset.change_attribute(changeset, :slug, slug)
    end
  end
end
