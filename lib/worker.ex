defmodule TaskEx.Worker do
    

    def start_link(opts \\ []) do
        :gen_server.start_link({ :local, Keyword.get(opts, :id, __MODULE__) }, __MODULE__, opts, [])
    end

    def create_state(), do: %{
        q: :queue.new,
        task: nil,
        pid: nil,
        ref: nil,
        tref: nil,
        result: nil,
        retry: 0
    }

    def init(_opts \\ []) do
        :pg2.join :taskex_pool, self
        {:ok, create_state}
    end

    defp create_process(t={f, retry, timeout, result}, state) do
        pid = spawn f
        ref = Process.monitor(pid)
        tref = :timer.send_after(timeout, self, {:timeout, pid, ref})
        %{state | pid: pid, task: t, ref: ref, tref: tref, retry: retry, result: result}
    end

    def handle_call({:task, t={_,_,_,_}}, _, state=%{pid: nil}), do: {:reply, :ok, create_process(t, state)} 
    def handle_call({:task, t={_,_,_,_}}, _, state=%{q: q}), do: {:reply, :ok, %{state| q: :queue.in(t, q)}}
     

    def handle_info({:DOWN, ref, :process, pid, :normal}, state=%{task: t, q: q, pid: pid, ref: ref, tref: tref, result: ok}) do 
        call_ok(ok, t)
        case :queue.out(q) do
            {:empty, _} -> {:noreply, %{state| pid: nil, tref: cancel_timer(tref) }}
            {{:value, task}, new_q} -> {:noreply, %{ create_process(task, %{state | tref: cancel_timer(tref)}) | q: new_q }}
        end
    end
    
    def handle_info({:DOWN, ref, :process, pid, e}, state=%{q: q, task: t, pid: pid, ref: ref, retry: 0, tref: tref, result: error}) do
        call_error(error, t, e)
        case :queue.out(q) do
            {:empty, _} -> {:noreply, %{state| pid: nil, tref: cancel_timer(tref) }}
            {{:value, task}, new_q} -> {:noreply, %{ create_process(task, %{state | tref: cancel_timer(tref) }) | q: new_q } }
        end
    end

    def handle_info({:DOWN, ref, :process, pid, _}, state=%{task: task, pid: pid, ref: ref, retry: r, tref: tref}), do: 
        {:noreply, %{ create_process(task, state) | retry: r-1, tref: cancel_timer(tref) } }


    def handle_info({:timeout, pid, ref}, state=%{pid: pid, ref: ref}) do
        Process.exit(pid, :kill)
        {:noreply, state}
    end

    defp cancel_timer(tref) do
        :timer.cancel(tref) 
        nil
    end

    def call_ok(nil, _), do: :ok
    def call_ok(ok, t) do
        ok.({:ok, t})
    end


    def call_error(nil, _, _), do: :ok
    def call_error(error, t, e) do
        error.({:error, t,e})
    end

    def handle_info(_, state), do: {:noreply, state}

end