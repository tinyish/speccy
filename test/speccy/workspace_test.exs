defmodule Speccy.WorkspaceTest do
  use ExUnit.Case, async: true

  alias Speccy.Workspace

  @moduletag :tmp_dir
  @wait 2000

  setup %{tmp_dir: dir} do
    File.cp_r!("test/fixtures/specs/tasks", dir)
    Phoenix.PubSub.subscribe(Speccy.PubSub, Workspace.topic(dir))
    {:ok, pid} = Workspace.open(dir)
    on_exit(fn -> DynamicSupervisor.terminate_child(Speccy.Workspace.Supervisor, pid) end)
    %{pid: pid, task: Path.join(dir, "data/Task.json")}
  end

  defp about(spec), do: spec.valid["data/Task.json"]["about"]

  defp codes(problems, file), do: for(%{file: ^file, code: code} <- problems, do: code)

  test "an outside edit to a file is broadcast, and get returns it",
       %{tmp_dir: dir, pid: pid, task: task} do
    File.write!(task, String.replace(File.read!(task), "Something the user has to do", "A chore"))

    assert_receive {:spec_changed, spec, problems, []}, @wait
    assert about(spec) == "A chore."
    assert Workspace.get(dir) == {spec, problems, []}
    assert Workspace.open(dir <> "/") == {:ok, pid}
  end

  test "a file that isn't valid JSON, or fails its schema, keeps its last good version",
       %{task: task} do
    good = File.read!(task)

    File.write!(task, String.replace(good, ~s("done": "bool"), ~s("done": 3)))
    assert_receive {:spec_changed, spec, problems, ["data/Task.json"]}, @wait
    assert spec.valid["data/Task.json"]["fields"]["done"] == "bool"
    assert codes(problems, "data/Task.json") != []

    File.write!(task, ~s({"data": "Task",))
    assert_receive {:spec_changed, spec, problems, ["data/Task.json"]}, @wait
    assert about(spec) == "Something the user has to do."
    assert codes(problems, "data/Task.json") == [:"invalid-json"]

    File.write!(task, String.replace(good, "Something the user has to do", "A chore"))
    assert_receive {:spec_changed, spec, problems, []}, @wait
    assert about(spec) == "A chore."
    assert codes(problems, "data/Task.json") == []
  end

  test "a new file and a deleted file are both seen", %{tmp_dir: dir, task: task} do
    note = Path.join(dir, "data/Note.json")
    File.write!(note, String.replace(File.read!(task), ~s("Task"), ~s("Note")))
    assert_receive {:spec_changed, spec, _, []}, @wait
    assert spec.valid["data/Note.json"]["data"] == "Note"

    File.rm!(task)
    assert_receive {:spec_changed, spec, _, []}, @wait
    refute spec.ordered["data/Task.json"]
  end

  test "a write of identical bytes broadcasts nothing", %{task: task} do
    File.write!(task, File.read!(task))
    # Past the read the workspace makes a moment after it starts.
    refute_receive {:spec_changed, _, _, _}, 1500
  end

  test "a workspace whose watcher dies stays dead, and leaves the others alive",
       %{tmp_dir: dir, pid: pid} do
    other = Path.join(dir, "other")
    File.cp_r!("test/fixtures/specs/tasks", other)
    {:ok, alive} = Workspace.open(other)
    on_exit(fn -> DynamicSupervisor.terminate_child(Speccy.Workspace.Supervisor, alive) end)

    {:links, links} = Process.info(pid, :links)
    watcher = Enum.find(links, &(initial_call(&1) == {FileSystem.Worker, :init, 1}))
    ref = Process.monitor(pid)
    # :shutdown, not :kill, so its backend stops without logging.
    Process.exit(watcher, :shutdown)

    assert_receive {:DOWN, ^ref, _, _, _}
    catch_exit(Workspace.get(dir))
    assert {%{}, _, []} = Workspace.get(other)
  end

  defp initial_call(pid),
    do: Process.info(pid, :dictionary) |> elem(1) |> Keyword.get(:"$initial_call")
end
