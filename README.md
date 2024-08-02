# Terraform AWS Cross Pipeline

This repository contains the main Terraform configuration (`main.tf`) for a cross-application pipeline. It is used by multiple demo applications, each with its own dynamic AWS ECS container definition.

## Overview

The pipeline is designed to be flexible and reusable across different applications. It leverages AWS ECS for container orchestration and is configured dynamically based on the specific needs of each application.

## Usage

The pipeline is used in GitHub Actions workflows as follows:

```yaml

  aws:
    name: Aws
    needs: ["env"]
    runs-on: ubuntu-latest
    permissions:
      packages: write
      contents: read
    steps:
      
      - name: Checkout xotocross-infrastructure-pipe
        uses: actions/checkout@v2
        with:
          repository: 'xotosphere/xotocross-infrastructure-pipe'
          path: '.'

      - name: Download secret-artifact
        uses: actions/download-artifact@v3
        with:
          name: secret-artifact

      - name: Mask .env file
        run: |
          while IFS='=' read -r key value
          do
              echo "::add-mask::$value"
          done < .env.xotocross

      - name: Load .env file
        run: grep -o '^[^#]*' .env.xotocross >> "$GITHUB_ENV"

      - name: Gather Environments
        run: |
          echo "access-key=$XOTOCROSS_AWS_ACCESS_KEY" >> "$GITHUB_OUTPUT"
          echo "key-id=$XOTOCROSS_AWS_KEY_ID" >> "$GITHUB_OUTPUT"
          echo "aws-id=$XOTOCROSS_AWS_PROFILE_ID" >> "$GITHUB_OUTPUT"
          echo "username=$XOTOCROSS_CROSS_LOGIN_USERNAME" >> "$GITHUB_OUTPUT"
          echo "password=$XOTOCROSS_CROSS_LOGIN_PASSWORD" >> "$GITHUB_OUTPUT"
        id: xtcross_aws_credential

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ steps.xtcross_aws_credential.outputs.key-id }}
          aws-secret-access-key: ${{ steps.xtcross_aws_credential.outputs.access-key }}
          aws-region: ${{ env.REGION }}

      - name: Set Environment
        run: echo "ENVIRONMENT=$(echo ${GITHUB_REF#refs/heads/} | cut -d'/' -f 2)" >> $GITHUB_ENV
          
      - name: Terraform Init
        env:
          ENVIRONMENT: ${{ env.ENVIRONMENT }}
        run: |
          terraform init \
          -backend-config="bucket=xtcross-${{ env.ENVIRONMENT }}-bucket" \
          -backend-config="key=${{ env.ENVIRONMENT }}/${{ env.SERVICE_NAME }}/${{ env.SERVICE_NAME }}.tfstate" \
          -backend-config="access_key=$XOTOCROSS_AWS_KEY_ID" \
          -backend-config="secret_key=$XOTOCROSS_AWS_ACCESS_KEY" \
          -backend-config="region=${{ env.REGION }}" \
          -reconfigure
      
      - name: Terraform Apply
        env:
          ENVIRONMENT: ${{ env.ENVIRONMENT }}
        run: |
          terraform apply -auto-approve \
          -var environment=${{ env.ENVIRONMENT }} \
          -var xtcross-cluster-name="xtcross-${{ env.ENVIRONMENT }}-ecs" \
          -var xtcross-password="${{ steps.xtcross_aws_credential.outputs.password }}" \
          -var xtcross-username="${{ steps.xtcross_aws_credential.outputs.username }}" \
          -var xtcross-service-version="0.0.0" \
          -var xtcross-account-id=${{ steps.xtcross_aws_credential.outputs.aws-id }} \
          -var xtcross-container-portlist='80,8081' \
          -var xtcross-host-portlist='8080,8081' \
          -var xtcross-organization="xotosphere" \
          -var xtcross-domain-name="xotosphere" \
          -var xtcross-healthcheck-interval=60 \
          -var xtcross-enable-monitor=false
```

## Steps Explanation

Checkout xotocross-infrastructure-pipe: This step checks out the xotocross-infrastructure-pipe repository, which contains the Terraform configuration for the pipeline.

This pipeline provides a flexible and reusable infrastructure for deploying multiple demo applications on AWS ECS. By leveraging Terraform and GitHub Actions, it automates the process of setting up and managing the AWS resources needed by each application.
his draft to better fit your project's specifics.
