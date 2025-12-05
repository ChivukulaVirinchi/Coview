defmodule CoviewWeb.PageController do
  use CoviewWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
