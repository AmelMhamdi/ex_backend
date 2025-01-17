defmodule ExBackend.WorkflowStep do
  @moduledoc """
  The Workflow Step context.
  """

  require Logger

  alias ExBackend.Workflows.Workflow
  alias ExBackend.Artifacts

  def start_next_step(%Workflow{id: workflow_id} = workflow) do
    workflow = ExBackend.Repo.preload(workflow, :jobs, force: true)

    step_index =
      Enum.map(workflow.jobs, fn job -> (job.step_id |> Integer.to_string()) <> job.name end)
      |> Enum.uniq()
      |> length

    steps = ExBackend.Map.get_by_key_or_atom(workflow.flow, :steps)

    case Enum.at(steps, step_index) do
      nil ->
        set_artifacts(workflow)
        Logger.warn("#{__MODULE__}: workflow #{workflow_id} is completed")
        {:ok, "completed"}

      step ->
        Logger.warn(
          "#{__MODULE__}: start to process step #{step["name"]} (index #{step_index}) for workflow #{
            workflow_id
          }"
        )

        step_name = ExBackend.Map.get_by_key_or_atom(step, :name)
        status = launch_step(workflow, step_name, step)

        Logger.info("#{step_name}: #{inspect(status)}")
        topic = "update_workflow_" <> Integer.to_string(workflow_id)

        ExBackendWeb.Endpoint.broadcast!("notifications:all", topic, %{
          body: %{workflow_id: workflow_id}
        })

        case status do
          {:ok, "skipped"} -> start_next_step(workflow)
          {:ok, "completed"} -> start_next_step(workflow)
          _ -> status
        end
    end
  end

  def skip_step(workflow, step) do
    step_name = ExBackend.Map.get_by_key_or_atom(step, :name)

    ExBackend.Repo.preload(workflow, :jobs, force: true)
    |> ExBackend.Jobs.create_skipped_job(ExBackend.Map.get_by_key_or_atom(step, :id), step_name)
  end

  def skip_step_jobs(workflow, step) do
    step_name = ExBackend.Map.get_by_key_or_atom(step, :name)

    ExBackend.Repo.preload(workflow, :jobs, force: true)
    |> ExBackend.Jobs.skip_jobs(ExBackend.Map.get_by_key_or_atom(step, :id), step_name)
  end

  defp launch_step(workflow, "acs_synchronize", step) do
    ExBackend.Workflow.Step.AcsSynchronize.launch(workflow, step)
  end

  defp launch_step(workflow, "asp_process", step) do
    ExBackend.Workflow.Step.AspProcess.launch(workflow, step)
  end

  defp launch_step(workflow, "audio_extraction", step) do
    ExBackend.Workflow.Step.AudioExtraction.launch(workflow, step)
  end

  defp launch_step(workflow, "dash_manifest", step) do
    ExBackend.Workflow.Step.DashManifest.launch(workflow, step)
  end

  defp launch_step(workflow, "download_ftp", step) do
    ExBackend.Workflow.Step.FtpDownload.launch(workflow, step)
  end

  defp launch_step(workflow, "download_http", step) do
    ExBackend.Workflow.Step.HttpDownload.launch(workflow, step)
  end

  defp launch_step(workflow, "ttml_to_mp4", step) do
    ExBackend.Workflow.Step.TtmlToMp4.launch(workflow, step)
  end

  defp launch_step(workflow, "set_language", step) do
    ExBackend.Workflow.Step.SetLanguage.launch(workflow, step)
  end

  defp launch_step(workflow, "generate_dash", step) do
    ExBackend.Workflow.Step.GenerateDash.launch(workflow, step)
  end

  defp launch_step(workflow, "upload_ftp", step) do
    ExBackend.Workflow.Step.FtpUpload.launch(workflow, step)
  end

  defp launch_step(workflow, "upload_file", step) do
    ExBackend.Workflow.Step.UploadFile.launch(workflow, step)
  end

  defp launch_step(workflow, "push_rdf", step) do
    ExBackend.Workflow.Step.PushRdf.launch(workflow, step)
  end

  defp launch_step(workflow, "copy", step) do
    ExBackend.Workflow.Step.Copy.launch(workflow, step)
  end

  defp launch_step(workflow, "clean_workspace", step) do
    ExBackend.Workflow.Step.CleanWorkspace.launch(workflow, step)
  end

  defp launch_step(workflow, "speech_to_text", step) do
    ExBackend.Workflow.Step.SpeechToText.launch(workflow, step)
  end

  defp launch_step(workflow, "register", step) do
    ExBackend.Workflow.Step.Register.launch(workflow, step)
  end

  defp launch_step(workflow, "send_notification", step) do
    ExBackend.Workflow.Step.Notification.launch(workflow, step)
  end

  defp launch_step(workflow, "ism_manifest", step) do
    ExBackend.Workflow.Step.IsmManifest.launch(workflow, step)
  end

  defp launch_step(workflow, "ism_extraction", step) do
    ExBackend.Workflow.Step.IsmExtraction.launch(workflow, step)
  end

  defp launch_step(workflow, step_name, step) do
    Logger.error("unable to match with the step #{inspect(step)} for workflow #{workflow.id}")

    ExBackend.Repo.preload(workflow, :jobs, force: true)
    |> ExBackend.Jobs.create_error_job(
      step_name,
      ExBackend.Map.get_by_key_or_atom(step, :id),
      "unable to start this step"
    )

    {:error, "unable to match with the step #{step_name}"}
  end

  def set_artifacts(workflow) do
    paths =
      get_uploaded_file_path(workflow.jobs)
      |> Enum.filter(fn path -> String.ends_with?(path, ".mpd") end)

    resources =
      case paths do
        [] -> %{}
        paths -> %{manifest: List.first(paths)}
      end

    params = %{
      resources: resources,
      workflow_id: workflow.id
    }

    Artifacts.create_artifact(params)
  end

  def get_uploaded_file_path(jobs, result \\ [])
  def get_uploaded_file_path([], result), do: result

  def get_uploaded_file_path([job | jobs], result) do
    result =
      if job.name == "upload_ftp" do
        path =
          job
          |> ExBackend.Map.get_by_key_or_atom(:parameters, [])
          |> Enum.find(fn param -> ExBackend.Map.get_by_key_or_atom(param, :id) == "destination_path" end)
          |> case do
            nil -> nil
            param -> ExBackend.Map.get_by_key_or_atom(param, :value)
          end

        case path do
          nil -> result
          path -> List.insert_at(result, -1, path)
        end
      else
        result
      end

    get_uploaded_file_path(jobs, result)
  end
end
