defmodule CoviewWeb.Presence do
  @moduledoc """
  Phoenix Presence for tracking users in CoView rooms.

  Tracks who is in each room, their role (leader/follower),
  and when they joined.
  """
  use Phoenix.Presence,
    otp_app: :coview,
    pubsub_server: Coview.PubSub
end
