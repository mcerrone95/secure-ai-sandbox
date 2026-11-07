# ---------------------------------------------------------------------------
# Bedrock guardrail: content filters, prompt-attack protection, PII handling.
# ---------------------------------------------------------------------------
resource "aws_bedrock_guardrail" "this" {
  name                      = "${local.name}-guardrail"
  description               = "Baseline guardrail for the AI sandbox"
  blocked_input_messaging   = "Sorry, that request was blocked by the sandbox guardrail."
  blocked_outputs_messaging = "Sorry, that response was blocked by the sandbox guardrail."

  content_policy_config {
    filters_config {
      type            = "HATE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    filters_config {
      type            = "VIOLENCE"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
    # Prompt-attack filtering only applies to inputs, so output must be NONE.
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "NONE"
    }
  }

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "PHONE"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "US_SOCIAL_SECURITY_NUMBER"
      action = "BLOCK"
    }
  }
}

# Using a guardrail requires bedrock:ApplyGuardrail on the guardrail itself,
# separate from permission to invoke the model.
data "aws_iam_policy_document" "guardrail" {
  statement {
    sid       = "ApplyOneGuardrail"
    actions   = ["bedrock:ApplyGuardrail"]
    resources = [aws_bedrock_guardrail.this.guardrail_arn]
  }
}

resource "aws_iam_policy" "guardrail" {
  name   = "${local.name}-guardrail"
  policy = data.aws_iam_policy_document.guardrail.json
}

resource "aws_iam_role_policy_attachment" "guardrail" {
  role       = aws_iam_role.workload.name
  policy_arn = aws_iam_policy.guardrail.arn
}

output "guardrail_id" {
  value = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_version" {
  value = aws_bedrock_guardrail.this.version
}
