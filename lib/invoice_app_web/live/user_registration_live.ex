defmodule InvoiceAppWeb.UserRegistrationLive do
  @moduledoc false
  use InvoiceAppWeb, :live_view

  alias InvoiceApp.Accounts
  alias InvoiceApp.Accounts.User

  def render(assigns) do
    ~H"""
    <div class="h-screen mx-8 flex flex-col place-content-center gap-6 lg:gap-4">
      <div class="hidden lg:flex items-center justify-start gap-1 my-0 font-medium text-lg text-[#7C5DFA]">
        <.back navigate={~p"/"}>Back</.back>
      </div>
      <div class="hidden h-20 lg:flex gap-4 items-center justify-center">
        <img src="/images/logo.svg" alt="Invoice Logo" class="h-12 mr-2" />
        <h1 class="text-[#7C5DFA] font-semibold text-6xl md:text-8xl lg:text-6xl">
          Invoice
        </h1>
      </div>
      <header class="text-center">
        <h1 class="text-3xl font-bold">Create an account</h1>
        <p class="text-base">Begin creating invoices for free!</p>
      </header>
      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        class="flex flex-col gap-2 text-left"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <div class="grid lg:grid-cols-2 gap-2 lg:gap-4">
          <.input
            field={@form[:full_name]}
            type="text"
            label="Name"
            placeholder="Enter Your Name"
            required
          />
          <.input
            field={@form[:username]}
            type="text"
            label="Username"
            placeholder="Enter Your Username"
            required
          />
        </div>
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          placeholder="Enter Your Email Address"
          required
        />
        <div class="relative">
          <.input
            field={@form[:password]}
            type={if @show_password, do: "text", else: "password"}
            placeholder="Enter Your Password"
            label="Password"
            value={@show_password}
            required
          />
          <span
            class="absolute inset-y-0 right-0 top-8 flex items-center pr-3 text-gray-700 cursor-pointer"
            phx-click="toggle_password_visibility"
          >
            <%= if @show_password do %>
              <.icon name="hero-eye" class="h-5 w-5" />
            <% else %>
              <.icon name="hero-eye-slash" class="h-5 w-5" />
            <% end %>
          </span>
          <div class="mt-2 text-sm">
            <p>Password must contain:</p>
            <div class="grid grid-cols-2 gap-x-4 gap-y-2 mt-2">
              <div class="flex items-center">
                <span
                  class="w-3 h-3 rounded-full mr-2"
                  style={
                    if String.length(@form[:password].value || "") >= 8,
                      do: "background-color: green;",
                      else: "background-color: gray;"
                  }
                >
                </span>
                8+ characters
              </div>
              <div class="flex items-center">
                <span
                  class="w-3 h-3 rounded-full mr-2"
                  style={
                    if Regex.match?(~r/[0-9]/, @form[:password].value || ""),
                      do: "background-color: green;",
                      else: "background-color: gray;"
                  }
                >
                </span>
                Number
              </div>
              <div class="flex items-center">
                <span
                  class="w-3 h-3 rounded-full mr-2"
                  style={
                    if Regex.match?(~r/[A-Z]/, @form[:password].value || ""),
                      do: "background-color: green;",
                      else: "background-color: gray;"
                  }
                >
                </span>
                Upper-case
              </div>
              <div class="flex items-center">
                <span
                  class="w-3 h-3 rounded-full mr-2"
                  style={
                    if Regex.match?(~r/[!?@#$%^&*_]/, @form[:password].value || ""),
                      do: "background-color: green;",
                      else: "background-color: gray;"
                  }
                >
                </span>
                Special character (!?@#$%^&*_)
              </div>
            </div>
          </div>
        </div>

        <.input
          field={@form[:terms_and_conditions]}
          type="checkbox"
          label="I agree with Invoice's Terms of Use and Privacy Policy"
          required
        />
        <:actions>
          <.button phx-disable-with="Creating account..." class="w-full">
            Sign Up
          </.button>
        </:actions>
      </.simple_form>
      <p class="text-xl text-center">
        Already have an account?
        <.link navigate={~p"/users/log_in"} class="text-[#7C5DFA] hover:underline">
          Log in
        </.link>
      </p>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, show_password: false)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("toggle_password_visibility", _params, socket) do
    {:noreply, assign(socket, show_password: !socket.assigns.show_password)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
