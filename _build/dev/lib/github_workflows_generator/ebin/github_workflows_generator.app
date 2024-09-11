{application,github_workflows_generator,
             [{optional_applications,[]},
              {applications,[kernel,stdlib,elixir,logger]},
              {description,"Generate GitHub Actions workflows"},
              {modules,['Elixir.GithubWorkflowsGenerator',
                        'Elixir.GithubWorkflowsGenerator.YmlEncoder',
                        'Elixir.Mix.Tasks.GithubWorkflows.Generate']},
              {registered,[]},
              {vsn,"0.1.3"}]}.
