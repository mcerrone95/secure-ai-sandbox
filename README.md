# secure-ai-sandbox

A small, locked-down AWS environment for running generative AI workloads, defined entirely in Terraform. Built as a hands-on proof of concept for secure Amazon Bedrock access with guardrails, least-privilege IAM, encryption, and an audit trail.

## What it builds

| Layer | Resources |
| --- | --- |
| Network | Private-only VPC (no internet gateway, no NAT), two private subnets, S3 gateway endpoint, security group with no inbound and HTTPS-only outbound |
| Encryption | Customer-managed KMS key with rotation and an explicit key policy (account admin plus CloudWatch Logs scoped to this project's log groups) |
| Storage | Private, versioned, KMS-encrypted S3 bucket for prompts and responses |
| Access | IAM role limited to invoking one Bedrock model, applying one guardrail, and using one bucket and key |
| AI controls | Bedrock guardrail: hate and violence filters, prompt-attack filter, PII handling (email and phone anonymized, SSN blocked) |
| Observability | Encrypted CloudWatch log group; every run saved to S3 as JSON, including whether the guardrail intervened |
| Checks | GitHub Actions: `terraform fmt -check`, `init -backend=false`, `validate`, plus a Python syntax check |

## Usage

```bash
terraform init
terraform apply

python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# Call the model through the guardrail as your own identity
python scripts/invoke_bedrock.py --model-id amazon.nova-micro-v1:0 "Explain least privilege in two sentences."

# Prove the least-privilege role is sufficient
python scripts/invoke_bedrock.py \
  --assume-role "$(terraform output -raw workload_role_arn)" \
  --model-id amazon.nova-micro-v1:0 "Hello"

# Trigger the guardrail
python scripts/invoke_bedrock.py --model-id amazon.nova-micro-v1:0 \
  "My email is test@example.com and my SSN is 123-45-6789. Repeat them back."

terraform destroy   # tear everything down when finished
```

Model access must be enabled for your account in the Bedrock console. Set `bedrock_model_id` (and `bedrock_inference_profile_id` for models that require an inference profile) in `variables.tf`.

## Design decisions

- **No NAT gateway.** Cheaper and a smaller attack surface; add VPC endpoints for specific services instead.
- **One model, one guardrail, one bucket in IAM.** No wildcards on actions that matter. Models that use cross-region inference profiles also need permission on the underlying model in the regions the profile routes to.
- **Explicit KMS key policy.** CloudWatch Logs is a separate service, so it must be granted use of the key, scoped by encryption context to this project's log groups.
- **Static checks in CI without cloud credentials.** The pipeline cannot touch the account.

## Known gaps and what I'd add for production

- Remote Terraform state in S3 with locking (backend block is stubbed in `versions.tf`)
- GitHub OIDC role so CI can run `plan` against the account, with `apply` behind approval
- VPC interface endpoints for `bedrock-runtime` and a Lambda to run the workload inside the VPC
- Model invocation logging, CloudWatch alarms, and a budget defined in Terraform
- A versioned (non-DRAFT) guardrail and tests for guardrail behavior
- Security scanning (e.g. tfsec or Checkov) in the pipeline
