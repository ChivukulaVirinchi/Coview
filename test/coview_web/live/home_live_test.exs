defmodule CoviewWeb.HomeLiveTest do
  use CoviewWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders home page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "CoView"
      assert html =~ "Browse websites together"
      assert html =~ "Join a Room"
    end

    test "renders join form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#join-room-form")
      assert has_element?(view, "input[name='room_code']")
    end

    test "renders extension link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#get-extension-link")
    end
  end

  describe "join_room event" do
    test "navigates to room when code entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#join-room-form", %{room_code: "abc123"})
      |> render_submit()

      assert_redirect(view, ~p"/room/abc123")
    end

    test "trims whitespace from room code", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#join-room-form", %{room_code: "  test-room  "})
      |> render_submit()

      assert_redirect(view, ~p"/room/test-room")
    end

    test "shows error when no code entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("#join-room-form", %{room_code: ""})
        |> render_submit()

      assert html =~ "Please enter a room code"
    end

    test "shows error when only whitespace entered", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html =
        view
        |> form("#join-room-form", %{room_code: "   "})
        |> render_submit()

      assert html =~ "Please enter a room code"
    end
  end
end
