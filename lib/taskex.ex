defmodule TaskEx do
  use Application
  import Supervisor.Spec, warn: false

  @timeout Application.get_env(:taskex, :timeout, 5000)
  @retry Application.get_env(:taskex, :retry, 5) 

  def workers(count, worker, opts \\ []) do
    Enum.map(1..count, fn(x) ->
       id = String.to_atom("#{Node.self}_#{worker}_#{x}")
       worker(worker, [ Dict.put(opts, :id, id) ], [id: id] )
    end)
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    :pg2.start
    :pg2.create :taskex_pool
    children = workers(Application.get_env(:taskex, :thread, 1), TaskEx.Worker)
    opts = [strategy: :one_for_one, name: TaskEx.Supervisor, max_restarts: 50000, max_seconds: 10]
    Supervisor.start_link(children, opts)
  end

  def spawn(task), do: GenServer.call(:pg2.get_closest_pid(:taskex_pool), {:task, {task, @retry, @timeout, nil}})
  def spawn(task, callback), do: GenServer.call(:pg2.get_closest_pid(:taskex_pool), {:task, {task, @retry, @timeout, callback}})
  def spawn(task, retry, timeout, callback), do: GenServer.call(:pg2.get_closest_pid(:taskex_pool), {:task, {task, retry, timeout, callback}})

end
