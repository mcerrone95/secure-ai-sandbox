#!/usr/bin/env python3
"""Send a prompt to Bedrock through the sandbox guardrail and save the result to S3.

Usage (from the project root, after `terraform apply`):

    python scripts/invoke_bedrock.py "Explain least privilege in two sentences."

    # Prove the least-privilege role works (instead of your admin user):
    python scripts/invoke_bedrock.py --assume-role "$(terraform output -raw workload_role_arn)" "Hello"
"""
import argparse
import datetime
import json
import subprocess
import sys

import boto3
from botocore.exceptions import ClientError


def tf_output(name: str) -> str:
    """Read a value from `terraform output` so nothing is hard-coded."""
    return subprocess.check_output(
        ["terraform", "output", "-raw", name], text=True
    ).strip()


def get_session(role_arn: str | None, region: str) -> boto3.Session:
    base = boto3.Session(region_name=region)
    if not role_arn:
        return base
    creds = base.client("sts").assume_role(
        RoleArn=role_arn, RoleSessionName="sandbox-demo"
    )["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
        region_name=region,
    )


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("prompt")
    p.add_argument("--region", default="us-east-1")
    p.add_argument("--model-id", default="anthropic.claude-3-haiku-20240307-v1:0")
    p.add_argument("--assume-role", help="Role ARN to assume before calling Bedrock")
    args = p.parse_args()

    bucket = tf_output("bucket_name")
    guardrail_id = tf_output("guardrail_id")
    guardrail_version = tf_output("guardrail_version")

    session = get_session(args.assume_role, args.region)
    bedrock = session.client("bedrock-runtime")
    s3 = session.client("s3")

    try:
        resp = bedrock.converse(
            modelId=args.model_id,
            messages=[{"role": "user", "content": [{"text": args.prompt}]}],
            inferenceConfig={"maxTokens": 300, "temperature": 0.2},
            guardrailConfig={
                "guardrailIdentifier": guardrail_id,
                "guardrailVersion": guardrail_version,
            },
        )
    except ClientError as err:
        print(f"Bedrock call failed: {err.response['Error']['Code']}: {err}", file=sys.stderr)
        return 1

    text = resp["output"]["message"]["content"][0]["text"]
    blocked = resp.get("stopReason") == "guardrail_intervened"

    record = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "model_id": args.model_id,
        "prompt": args.prompt,
        "response": text,
        "guardrail_intervened": blocked,
        "usage": resp.get("usage", {}),
    }
    key = f"runs/{datetime.datetime.now(datetime.timezone.utc):%Y%m%dT%H%M%S}.json"
    s3.put_object(Bucket=bucket, Key=key, Body=json.dumps(record, indent=2).encode())

    print(f"Guardrail intervened: {blocked}")
    print(f"Response: {text}")
    print(f"Saved to s3://{bucket}/{key}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
