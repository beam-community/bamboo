ExUnit.start()

Supervisor.start_child(
  Bamboo.Supervisor,
  Bamboo.Strategies.TaskSupervisor.child_spec
)

Application.ensure_all_started(:phoenix)
Application.ensure_all_started(:cowboy)
