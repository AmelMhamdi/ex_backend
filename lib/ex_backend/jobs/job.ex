defmodule ExBackend.Jobs.Job do
  use Ecto.Schema
  import Ecto.Changeset
  alias ExBackend.Jobs.Job
  alias ExBackend.Jobs.Status
  alias ExBackend.Workflows.Workflow

  schema "jobs" do
    field(:name, :string)
    field(:step_id, :integer)
    field(:parameters, {:array, :map}, default: [])
    belongs_to(:workflow, Workflow, foreign_key: :workflow_id)
    has_many(:status, Status, on_delete: :delete_all)

    timestamps()
  end

  @doc false
  def changeset(%Job{} = job, attrs) do
    job
    |> cast(attrs, [:name, :step_id, :parameters, :workflow_id])
    |> foreign_key_constraint(:workflow_id)
    |> validate_required([:name, :step_id, :parameters, :workflow_id])
  end
end
