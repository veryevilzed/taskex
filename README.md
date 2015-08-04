TaskEx
======

```
TaskEx.spawn(task)
TaskEx.spawn(task, callback)
TaskEx.spawn(task, retry, timeout, callback)
```

Basic Usage

```
TaskEx.spawn fn()-> IO.puts "start"; :timer.sleep(2000); IO.puts "end" end
```

With Callback

```
TaskEx.spawn fn()-> IO.puts "start"; :timer.sleep(2000); IO.puts "end" end, fn(d)-> IO.puts "result: #{inspect d}" end
```


Callback
--------

```
{:ok, {#Function<20.90072148/0 in :erl_eval.expr/5>, 5, 5000, #Function<6.90072148/1 in :erl_eval.expr/5>}}
```

```
{:error, {#Function<20.90072148/0 in :erl_eval.expr/5>, 5, 10, #Function<6.90072148/1 in :erl_eval.expr/5>}, :killed}
```
