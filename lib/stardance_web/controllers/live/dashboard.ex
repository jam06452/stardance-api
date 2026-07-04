defmodule StardanceWeb.DashboardLive do
  use StardanceWeb, :live_view

  alias Stardance.Accounts
  alias Stardance.Repo
  alias Stardance.Schema.AuthUser

  import Ecto.Query

  def mount(_params, session, socket) do
    user = Accounts.get_user!(session["current_user_id"])

    endorsed_users =
      Repo.all(
        from u in AuthUser,
          where: u.endorsed == true,
          order_by: [desc: u.inserted_at],
          select: %{
            display_name: u.display_name,
            name: u.name,
            email: u.email,
            avatar: u.avatar,
            id: u.id
          }
      )

    {:ok,
     socket
     |> assign(:current_user, user)
     |> assign(:endorsed_users, endorsed_users)
     |> assign(:endorsed_count, length(endorsed_users))}
  end

  def handle_event("toggle_endorsement", _params, socket) do
    user = socket.assigns.current_user
    new_status = !user.endorsed

    case Accounts.update_auth_user(user, %{endorsed: new_status}) do
      {:ok, updated_user} ->
        endorsed_users =
          Repo.all(
            from u in AuthUser,
              where: u.endorsed == true,
              order_by: [desc: u.inserted_at],
              select: %{
                display_name: u.display_name,
                name: u.name,
                email: u.email,
                avatar: u.avatar,
                id: u.id
              }
          )

        {:noreply,
         socket
         |> assign(:current_user, updated_user)
         |> assign(:endorsed_users, endorsed_users)
         |> assign(:endorsed_count, length(endorsed_users))
         |> put_flash(
           :info,
           if(new_status, do: "Endorsement added!", else: "Endorsement removed.")
         )}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update endorsement.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="relative min-h-screen overflow-hidden bg-[#120b16] text-white">
      <div class="absolute inset-0 bg-gradient-to-br from-[#1b1324] via-[#120b16] to-[#0d0912]"></div>

      <%!-- Floating decorations — mirrors the landing page --%>
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/earth-1bcc8966.png"
        class="absolute top-24 left-1/2 -translate-x-1/2 w-20 opacity-90 pointer-events-none select-none"
        draggable="false"
      />
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/moon-6cc9fac1.png"
        class="absolute top-56 left-[55%] w-28 pointer-events-none select-none"
        draggable="false"
      />
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/nasa-hero-e6195581.png"
        class="absolute -bottom-40 -right-24 w-[550px] lg:w-[760px] pointer-events-none select-none opacity-30"
        draggable="false"
      />
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/star-character-e6aa34d1.png"
        class="absolute top-8 left-6 w-10 -rotate-12 select-none"
        draggable="false"
      />
      <img
        src="https://stardance.hackclub.com/assets/landing/hero/star-character-e6aa34d1.png"
        class="absolute bottom-40 right-10 w-12 rotate-12 select-none"
        draggable="false"
      />

      <div class="relative z-10 flex min-h-screen flex-col px-8 lg:px-16 py-12">
        <%!-- Header --%>
        <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <h1 class="text-5xl md:text-6xl font-extrabold drop-shadow-[0_0_30px_rgba(255,255,255,0.35)]">
              Dashboard
            </h1>
            <p class="mt-3 text-lg text-gray-300">
              Manage your Stardance API account.
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-4">
            <a
              href="/docs"
              class="inline-flex items-center justify-center gap-2 rounded-full bg-white px-6 py-3 text-base font-bold text-[#120b16] shadow-lg transition-transform hover:scale-105 hover:bg-gray-200"
            >
              <.icon name="hero-document-text" class="size-5" /> API Documentation
            </a>

            <button
              phx-click="toggle_endorsement"
              class={[
                "inline-flex items-center justify-center gap-2 rounded-full px-6 py-3 text-base font-bold shadow-lg transition-transform hover:scale-105 cursor-pointer",
                if(@current_user.endorsed,
                  do: "bg-red-400 text-white hover:bg-red-500",
                  else: "bg-emerald-400 text-white hover:bg-emerald-500"
                )
              ]}
            >
              <.icon :if={@current_user.endorsed} name="hero-heart" class="size-5" />
              <.icon :if={!@current_user.endorsed} name="hero-star" class="size-5" />
              {if @current_user.endorsed, do: "Remove Endorsement", else: "Endorse Stardance"}
            </button>
          </div>
        </div>

        <%!-- Endorsed Users Carousel --%>
        <div class="mt-20">
          <div class="inline-flex items-center gap-2 rounded-full bg-white px-6 py-3 text-black font-bold shadow-xl">
            <.icon name="hero-star" class="size-5 text-amber-500" /> Endorsed by {@endorsed_count}
          </div>

          <div class="relative mt-8 overflow-hidden">
            <%!-- Fade edges --%>
            <div class="pointer-events-none absolute inset-y-0 left-0 z-20 w-32 bg-gradient-to-r from-[#120b16] to-transparent">
            </div>
            <div class="pointer-events-none absolute inset-y-0 right-0 z-20 w-32 bg-gradient-to-l from-[#120b16] to-transparent">
            </div>

            <div
              :if={@endorsed_users != []}
              class="flex w-max gap-5 animate-[carousel_40s_linear_infinite]"
            >
              <%= for _ <- 1..2 do %>
                <%= for user <- @endorsed_users do %>
                  <div class="flex w-32 shrink-0 flex-col items-center gap-3">
                    <div class="h-32 w-32 overflow-hidden rounded-[2rem] bg-white/10 shadow-xl backdrop-blur-sm">
                      <StardanceWeb.PageHTML.profile_picture user={user} />
                    </div>
                    <div class="w-full overflow-hidden rounded-full bg-white px-3 py-2 text-center text-sm font-semibold text-[#120b16] shadow">
                      <span class="block truncate">
                        {StardanceWeb.PageHTML.display_name(user)}
                      </span>
                    </div>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div
              :if={@endorsed_count == 0}
              class="flex items-center justify-center py-16 text-gray-400"
            >
              <div class="flex flex-col items-center gap-3">
                <.icon name="hero-star" class="size-10 opacity-30" />
                <p class="text-lg">No endorsements yet. Be the first!</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
