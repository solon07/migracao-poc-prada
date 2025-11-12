#!/bin/bash
set -euo pipefail

INSTANCE_ID="i-06dfc5a34a6c60fbe"
EXPORT_DIR="exports"

echo "🔍 Coletando configurações EC2 $INSTANCE_ID..."

# Instance details
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --output json > "$EXPORT_DIR/ec2-full-details.json"

echo "✅ Detalhes salvos em $EXPORT_DIR/ec2-full-details.json"

# Security groups
SG_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
  --output text)

aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --output json > "$EXPORT_DIR/security-groups.json"

echo "✅ Security groups salvos"

# Volumes
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[0].Ebs.VolumeId' \
  --output text)

aws ec2 describe-volumes \
  --volume-ids "$VOLUME_ID" \
  --output json > "$EXPORT_DIR/volume-details.json"

echo "✅ Volume details salvos"
echo "🎉 Backup concluído!"
