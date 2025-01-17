defmodule GithubWorkflows do
    @moduledoc """
    Run `mix github_workflows.generate` after updating this module.
    """
  
    @app_name "invoice-app"
    @environment_name "pr-${{ github.event.number }}"
    @preview_app_name "#{@app_name}-#{@environment_name}"
    @preview_app_host "#{@preview_app_name}.fly.dev"
    @repo_name "invoice-app"
  
    def get do
      %{
        "main.yml" => main_workflow(),
        "pr.yml" => pr_workflow(),
        "pr_closure.yml" => pr_closure_workflow()
      }
    end
  
    defp main_workflow do
      [
        [
          name: "Main",
          on: [
            push: [
              branches: ["main"]
            ]
          ],
          jobs:
            elixir_ci_jobs() ++
              [
                deploy_production_app: deploy_production_app_job()
              ]
        ]
      ]
    end
  
    defp pr_workflow do
      [
        [
          name: "PR",
          on: [
            pull_request: [
              branches: ["main"],
              types: ["opened", "reopened", "synchronize"]
            ]
          ],
          jobs:
            elixir_ci_jobs() ++
              [
                deploy_preview_app: deploy_preview_app_job()
              ]
        ]
      ]
    end
  
    defp pr_closure_workflow do
      [
        [
          name: "PR closure",
          on: [
            pull_request: [
              branches: ["main"],
              types: ["closed"]
            ]
          ],
          jobs: [
            delete_preview_app: delete_preview_app_job()
          ]
        ]
      ]
    end
  
    defp elixir_ci_jobs do
      [
        compile: compile_job(),
        credo: credo_job(),
        deps_audit: deps_audit_job(),
        dialyzer: dialyzer_job(),
        format: format_job(),
        hex_audit: hex_audit_job(),
        migrations: migrations_job(),
        prettier: prettier_job(),
        sobelow: sobelow_job(),
        test: test_job(),
        unused_deps: unused_deps_job()
      ]
    end
  
    defp compile_job do
      elixir_job("Install deps and compile",
        steps: [
          [
            name: "Install Elixir dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.get"
          ],
          [
            name: "Compile",
            env: [MIX_ENV: "test"],
            run: "mix compile"
          ]
        ]
      )
    end
  
    defp credo_job do
      elixir_job("Credo",
        needs: :compile,
        steps: [
          [
            name: "Check code style",
            env: [MIX_ENV: "test"],
            run: "mix credo --strict"
          ]
        ]
      )
    end
  
    defp delete_preview_app_job do
      [
        name: "Delete preview app",
        "runs-on": "ubuntu-latest",
        concurrency: [group: "pr-${{ github.event.number }}"],
        steps: [
          checkout_step(),
          [
            name: "Delete preview app",
            uses: "optimumBA/fly-preview-apps@main",
            env: [
              FLY_API_TOKEN: "${{ secrets.FLY_API_TOKEN }}",
              REPO_NAME: @repo_name
            ],
            with: [
              name: @preview_app_name
            ]
          ],
          [
            name: "Generate token",
            uses: "navikt/github-app-token-generator@v1.1.1",
            id: "generate_token",
            with: [
              "app-id": "${{ secrets.GH_APP_ID }}",
              "private-key": "${{ secrets.GH_APP_PRIVATE_KEY }}"
            ]
          ],
          [
            name: "Delete GitHub environment",
            uses: "strumwolf/delete-deployment-environment@v2.2.3",
            with: [
              token: "${{ steps.generate_token.outputs.token  }}",
              environment: @environment_name,
              ref: "${{ github.head_ref }}"
            ]
          ]
        ]
      ]
    end
  
    defp deploy_job(env, opts) do
      [
        name: "Deploy #{env} app",
        needs: [
          :compile,
          :credo,
          :deps_audit,
          :dialyzer,
          :format,
          :hex_audit,
          :migrations,
          :prettier,
          :sobelow,
          :test,
          :unused_deps
        ],
        "runs-on": "ubuntu-latest"
      ] ++ opts
    end
  
    defp deploy_preview_app_job do
      deploy_job("preview",
        permissions: "write-all",
        concurrency: [group: @environment_name],
        environment: preview_app_environment(),
        steps: [
          checkout_step(),
          delete_previous_deployments_step(),
          [
            name: "Deploy preview app",
            uses: "optimumBA/fly-preview-apps@main",
            env: fly_env(),
            with: [
              name: @preview_app_name,
              secrets:
                "APPSIGNAL_APP_ENV=preview APPSIGNAL_PUSH_API_KEY=${{ secrets.APPSIGNAL_PUSH_API_KEY }} PHX_HOST=${{ env.PHX_HOST }} SECRET_KEY_BASE=${{ secrets.SECRET_KEY_BASE }}"
            ]
          ]
        ]
      )
    end
  
    defp deploy_production_app_job do
      deploy_job("production",
        steps: [
          checkout_step(),
          [
            uses: "superfly/flyctl-actions/setup-flyctl@master"
          ],
          [
            run: "flyctl deploy --remote-only",
            env: [
              FLY_API_TOKEN: "${{ secrets.FLY_API_TOKEN }}"
            ]
          ]
        ]
      )
    end
  
    defp deps_audit_job do
      elixir_job("Deps audit",
        needs: :compile,
        steps: [
          [
            name: "Check for vulnerable Mix dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.audit"
          ]
        ]
      )
    end
  
    defp dialyzer_job do
      cache_key_prefix = "${{ runner.os }}-${{ env.elixir-version }}-${{ env.otp-version }}-plt"
  
      elixir_job("Dialyzer",
        needs: :compile,
        steps: [
          [
            name: "Restore PLT cache",
            uses: "actions/cache@v3",
            with:
              [
                path: "priv/plts"
              ] ++ cache_opts(cache_key_prefix)
          ],
          [
            name: "Create PLTs",
            env: [MIX_ENV: "test"],
            run: "mix dialyzer --plt"
          ],
          [
            name: "Run dialyzer",
            env: [MIX_ENV: "test"],
            run: "mix dialyzer"
          ]
        ]
      )
    end
  
    defp elixir_job(name, opts) do
      needs = Keyword.get(opts, :needs)
      services = Keyword.get(opts, :services)
      steps = Keyword.get(opts, :steps, [])
  
      cache_key_prefix = "${{ runner.os }}-${{ env.elixir-version }}-${{ env.otp-version }}-mix"
  
      job = [
        name: name,
        "runs-on": "ubuntu-latest",
        env: [
          "elixir-version": "1.16.2",
          "otp-version": "25.3.2.12"
        ],
        steps:
          [
            checkout_step(),
            [
              name: "Set up Elixir",
              uses: "erlef/setup-beam@v1",
              with: [
                "elixir-version": "${{ env.elixir-version }}",
                "otp-version": "${{ env.otp-version }}"
              ]
            ],
            [
              uses: "actions/cache@v3",
              with:
                [
                  path: ~S"""
                  _build
                  deps
                  """
                ] ++ cache_opts(cache_key_prefix)
            ]
          ] ++ steps
      ]
  
      job
      |> then(fn job ->
        if needs do
          Keyword.put(job, :needs, needs)
        else
          job
        end
      end)
      |> then(fn job ->
        if services do
          Keyword.put(job, :services, services)
        else
          job
        end
      end)
    end
  
    defp format_job do
      elixir_job("Format",
        needs: :compile,
        steps: [
          [
            name: "Check Elixir formatting",
            env: [MIX_ENV: "test"],
            run: "mix format --check-formatted"
          ]
        ]
      )
    end
  
    defp hex_audit_job do
      elixir_job("Hex audit",
        needs: :compile,
        steps: [
          [
            name: "Check for retired Hex packages",
            env: [MIX_ENV: "test"],
            run: "mix hex.audit"
          ]
        ]
      )
    end
  
    defp migrations_job do
      elixir_job("Migrations",
        needs: :compile,
        services: [
          db: db_service()
        ],
        steps: [
          [
            name: "Check if migrations are reversible",
            env: [MIX_ENV: "test"],
            run: "mix ci.migrations"
          ]
        ]
      )
    end
  
    defp prettier_job do
      [
        name: "Check formatting using Prettier",
        "runs-on": "ubuntu-latest",
        steps: [
          checkout_step(),
          [
            name: "Restore npm cache",
            uses: "actions/cache@v3",
            id: "npm-cache",
            with: [
              path: "~/.npm",
              key: "${{ runner.os }}-prettier"
            ]
          ],
          [
            name: "Install Prettier",
            if: "steps.npm-cache.outputs.cache-hit != 'true'",
            run: "npm i -g prettier"
          ],
          [
            name: "Run Prettier",
            run: "npx prettier -c ."
          ]
        ]
      ]
    end
  
    defp sobelow_job do
      elixir_job("Security check",
        needs: :compile,
        steps: [
          [
            name: "Check for security issues using sobelow",
            env: [MIX_ENV: "test"],
            run: "mix sobelow --config .sobelow-conf"
          ]
        ]
      )
    end
  
    defp test_job do
      elixir_job("Test",
        needs: :compile,
        services: [
          db: db_service()
        ],
        steps: [
          [
            name: "Run tests",
            env: [
              MIX_ENV: "test"
            ],
            run: "mix test --cover --warnings-as-errors"
          ]
        ]
      )
    end
  
    defp unused_deps_job do
      elixir_job("Check unused deps",
        needs: :compile,
        steps: [
          [
            name: "Check for unused Mix dependencies",
            env: [MIX_ENV: "test"],
            run: "mix deps.unlock --check-unused"
          ]
        ]
      )
    end
  
    defp checkout_step do
      [
        name: "Checkout",
        uses: "actions/checkout@v4"
      ]
    end
  
    defp delete_previous_deployments_step do
      [
        name: "Delete previous deployments",
        uses: "strumwolf/delete-deployment-environment@v2.2.3",
        with: [
          token: "${{ secrets.GITHUB_TOKEN }}",
          environment: @environment_name,
          ref: "${{ github.head_ref }}",
          onlyRemoveDeployments: true
        ]
      ]
    end
  
    defp cache_opts(prefix) do
      [
        key: "#{prefix}-${{ github.sha }}",
        "restore-keys": ~s"""
        #{prefix}-
        """
      ]
    end
  
    defp fly_env do
      [
        FLY_API_TOKEN: "${{ secrets.FLY_API_TOKEN }}",
        FLY_ORG: "optimum-bh-internship",
        FLY_REGION: "lhr",
        PHX_HOST: "#{@preview_app_name}.fly.dev",
        REPO_NAME: @repo_name
      ]
    end
  
    defp preview_app_environment do
      [
        name: @environment_name,
        url: "https://#{@preview_app_host}"
      ]
    end
  
    defp db_service do
      [
        image: "postgres:13",
        ports: ["5432:5432"],
        env: [POSTGRES_PASSWORD: "${{ secrets.POSTGRES_PASSWORD }}"],
        options:
          "--health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5"
      ]
    end
  end