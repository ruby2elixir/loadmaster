defmodule Loadmaster.Build do
  use Loadmaster.Web, :model
  alias Loadmaster.Repo
  alias Loadmaster.Build
  alias Loadmaster.Job

  schema "builds" do
    field :pull_request_id, :integer
    field :git_remote, :string
    belongs_to :repository, Loadmaster.Repository
    has_many :jobs, Loadmaster.Job

    timestamps
  end

  @required_fields ~w(pull_request_id repository_id git_remote)
  @optional_fields ~w()

  @doc """
  Creates a changeset based on the `model` and `params`.

  If no params are provided, an invalid changeset is returned
  with no validation performed.
  """
  def changeset(model, params \\ :empty) do
    model
    |> cast(params, [:pull_request_id, :repository_id, :git_remote], @optional_fields)
    |> assoc_constraint(:repository)
  end

  def for_repository(query, repository_id) do
    from p in query, where: p.repository_id == ^repository_id
  end

  def sorted(query) do
    from p in query, order_by: [desc: :id]
  end

  def run(build, repository) do
    {:ok, build} = Repo.transaction fn ->
      build = Repo.insert!(build)
      for image <- repository.images do
        build
        |> build_assoc(:jobs)
        |> Job.create_changeset(%{image_id: image.id, state: "pending"})
        |> Repo.insert!
      end
      build
    end
    build
  end

  def rerun(id) do
    build =
      Build
      |> Repo.get!(id)
      |> Repo.preload(jobs: :image)

    {:ok, _} = Repo.transaction fn ->
      for job <- build.jobs do
        job
        |> Job.create_changeset(%{image_id: job.image.id, state: "pending"})
        |> Repo.update!
      end
    end
    build
  end
end
