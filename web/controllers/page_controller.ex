defmodule ChunkServer.PageController do
  use ChunkServer.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end

  def start(conn, _params) do
    {git_root_dir_result, 0} = System.cmd("git", ["rev-parse", "--show-toplevel"])
    git_root_dir = String.replace_suffix(git_root_dir_result, "\n", "")

    cmd = "cd #{git_root_dir} && sh start.sh"
    opts = [out: {:send, self()}]
    %Porcelain.Process{pid: pid} = Porcelain.spawn_shell(cmd, opts)

    conn = conn
    |> put_resp_content_type("text/event-stream")
    |> send_chunked(200)

    {:ok, conn} = chunk(conn, "start\n")
    wait_complete_deploy(conn, pid)
  end

  @spec wait_complete_deploy(Plug.Conn, pid) :: Plug.Conn
  def wait_complete_deploy(conn, pid) do
    receive do
      {^pid, :data, :out, data} ->
        {:ok, conn} = chunk(conn, data)
        IO.puts "continue"
        wait_complete_deploy(conn, pid)
      {^pid, :result, %Porcelain.Result{status: _status}} ->
        IO.puts "end"
        conn
    end
  end

end
