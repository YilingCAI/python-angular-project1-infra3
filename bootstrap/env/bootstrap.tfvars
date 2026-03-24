aws_region          = "us-east-1"
project_name        = "mypythonproject1"
expected_account_id = "805206611269"

environments = ["dev", "staging", "prod"]

# Keep names stable to match existing landing-zone resources.
state_bucket_names = {
  dev     = "mypythonproject1-tfstate-ec2-dev"
  staging = "mypythonproject1-tfstate-ec2-staging"
  prod    = "mypythonproject1-tfstate-ec2-prod"
}

github_actions_role_name = "GitHubActionsRole"

github_oidc_subjects = [
  # infra3 repo — Terraform CI/CD
  "repo:YilingCAI/python-angular-project1-infra3:environment:dev",
  "repo:YilingCAI/python-angular-project1-infra3:environment:staging",
  "repo:YilingCAI/python-angular-project1-infra3:environment:prod",
  "repo:YilingCAI/python-angular-project1-infra3:ref:refs/heads/main",
  "repo:YilingCAI/python-angular-project1-infra3:pull_request"

oidc_thumbprints = [
  "6938fd4d98bab03faadb97b34396831e3780aea1"
]
