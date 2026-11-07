output "vpc_id" {
  value = aws_vpc.this.id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "workload_role_arn" {
  value = aws_iam_role.workload.arn
}

output "kms_key_arn" {
  value = aws_kms_key.data.arn
}
