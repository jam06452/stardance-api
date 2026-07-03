defmodule StardanceWeb.DashboardLive do
  use StardanceWeb, :live_view

  alias Stardance.Accounts

  def mount(_params, session, socket) do
    case session["current_user_id"] do
      nil ->
        {:ok, redirect(socket, to: "/signin")}

      user_id ->
        user = Accounts.get_user!(user_id)

        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:endorsed_users, Accounts.list_endorsed_users())}
    end
  end

  def handle_event("toggle_endorsement", _params, socket) do
    user = socket.assigns.current_user
    new_status = !user.endorsed

    case Accounts.update_auth_user(user, %{endorsed: new_status}) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:endorsed_users, Accounts.list_endorsed_users())}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update endorsement.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen overflow-hidden bg-[#120b16] text-white">
      <div class="absolute inset-0 bg-gradient-to-br from-[#1b1324] via-[#120b16] to-[#0d0912]"></div>
      
    <!-- Decorations -->
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/earth-1bcc8966.png"
        class="absolute top-16 right-20 w-20 opacity-90 pointer-events-none"
      />

      <img
        src="https://stardance.hackclub.com/assets/landing/hero/star-character-e6aa34d1.png"
        class="absolute top-20 left-10 w-10 -rotate-12"
      />

      <img
        src="https://stardance.hackclub.com/assets/landing/hero/star-character-e6aa34d1.png"
        class="absolute bottom-24 right-16 w-12 rotate-12"
      />

      <div class="relative z-10 max-w-7xl mx-auto px-8 py-12">
        
    <!-- Header -->
        <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 class="text-5xl md:text-6xl font-extrabold">
              Dashboard
            </h1>

            <p class="mt-3 text-lg text-gray-300">
              Manage your Stardance API account.
            </p>
          </div>

          <div class="flex flex-wrap gap-4">
            <a href="/docs" class="btn btn-primary btn-lg rounded-full">
              📚 API Documentation
            </a>

            <button
              phx-click="toggle_endorsement"
              class={[
                "btn btn-lg rounded-full transition-all",
                if(@current_user.endorsed, do: "btn-error", else: "btn-success")
              ]}
            >
              <%= if @current_user.endorsed do %>
                💔 Remove Endorsement
              <% else %>
                ⭐ Endorse Project
              <% end %>
            </button>
          </div>
        </div>
        
    <!-- Endorsed Users -->
        <div class="mt-20">
          <div class="inline-flex rounded-full bg-base-100 px-6 py-3 text-black font-bold shadow-xl">
            ⭐ Endorsed By
          </div>

          <% user_count = length(@endorsed_users)

          display_users =
            if user_count == 0 do
              []
            else
              @endorsed_users
              |> Stream.cycle()
              |> Enum.take(max(10, user_count))
            end %>

          <div class="relative mt-8 overflow-hidden">
            <div class="pointer-events-none absolute inset-y-0 left-0 z-20 w-32 bg-gradient-to-r from-[#120b16] to-transparent">
            </div>
            <div class="pointer-events-none absolute inset-y-0 right-0 z-20 w-32 bg-gradient-to-l from-[#120b16] to-transparent">
            </div>

            <div class="flex w-max gap-6 animate-[carousel_40s_linear_infinite]">
              <%= for _ <- 1..2 do %>
                <%= for user <- display_users do %>
                  <div class="w-36 shrink-0">
                    <div class="card bg-base-100 shadow-2xl text-black">
                      <figure class="p-4">
                        <div class="h-28 w-28 overflow-hidden rounded-[1.75rem]">
                          <img
                            src={
                              user.avatar ||
                                "https://api.dicebear.com/7.x/identicon/svg?seed=#{user.id}"
                            }
                            class="h-full w-full object-cover"
                          />
                        </div>
                      </figure>

                      <div class="card-body p-3 pt-0 items-center">
                        <p class="font-semibold text-center truncate w-full">
                          {user.display_name || user.name || user.email || "Unknown"}
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>

    <style>
      @keyframes carousel {
        from { transform: translateX(0); }
        to { transform: translateX(-50%); }
      }
    </style>
    """
  end
end
