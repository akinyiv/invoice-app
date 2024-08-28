defmodule InvoiceAppWeb.UserLoginLive do
  use InvoiceAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl flex flex-col lg:flex-row">
      <div>
        <div class="hidden lg:block lg:w-1/2">
          <img src="/images/sign_up.png" alt="Background" class="w-full h-full object-cover" />
        </div>
        <div class="w-full lg:w-1/2 flex flex-col justify-center px-8 lg:px-24">
          <div class="mb-4">
            <.back navigate={~p"/"}>Back</.back>
          </div>
          <div class="text-center mb-6">
            <div class="flex items-center justify-center mb-4">
              <img src="/images/logo.svg" alt="Invoice Logo" class="h-12 mr-2" />
              <span class="text-purple-700 text-2xl font-semibold">Invoices</span>
            </div>
            <h2 class="text-3xl font-semibold">Sign in to Invoice</h2>
          </div>
        </div>

        <.simple_form
          for={@form}
          id="login_form"
          phx-update="ignore"
          action={~p"/users/log_in"}
          class="w-full"
        >
          <.input
            field={@form[:email]}
            type="email"
            placeholder="Enter Your Email"
            label="Email"
            required
          />
          <div class="relative">
            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              placeholder="Enter Your Password"
              required
            />
            <span class="absolute inset-y-0 right-0 top-8 flex items-center pr-3 text-gray-700 cursor-pointer">
              <.icon name="hero-eye-slash" />
            </span>
          </div>
          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Remember me" />
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold text-purple-500">
              Forgot password?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Creating account..." class="w-full">
              Continue
            </.button>
          </:actions>
        </.simple_form>
      </div>
      <div class="mt-4 text-center">
        <p class="text-gray-600">
          Already have an account?
          <.link navigate={~p"/users/register"} class="text-purple-600 hover:underline">
            Sign Up
          </.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
