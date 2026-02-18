#!/bin/bash

# Technickly Labs Website Deployment Script
# Deploys Jekyll site to AWS S3 with CloudFront invalidation

set -e  # Exit on error

# Configuration
BUCKET_NAME="technickly.ai"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"
AWS_REGION="us-east-1"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Technickly Labs Website Deployment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Install it from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check if bundle is installed
if ! command -v bundle &> /dev/null; then
    echo -e "${RED}Error: Bundler is not installed${NC}"
    echo "Install it with: gem install bundler"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "vendor/bundle" ]; then
    echo -e "${BLUE}Installing dependencies...${NC}"
    bundle install
fi

# Clean previous build
echo -e "${BLUE}Cleaning previous build...${NC}"
rm -rf _site .jekyll-cache

# Build the site
echo -e "${BLUE}Building Jekyll site...${NC}"
JEKYLL_ENV=production bundle exec jekyll build

if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Build successful${NC}"
echo ""

# Check if S3 bucket exists
echo -e "${BLUE}Checking S3 bucket...${NC}"
if ! aws s3 ls "s3://${BUCKET_NAME}" 2>&1 > /dev/null; then
    echo -e "${RED}Error: Bucket s3://${BUCKET_NAME} does not exist${NC}"
    echo "Create it with: aws s3 mb s3://${BUCKET_NAME}"
    exit 1
fi

echo -e "${GREEN}✓ Bucket exists${NC}"
echo ""

# Sync to S3
echo -e "${BLUE}Deploying to S3...${NC}"
aws s3 sync _site/ "s3://${BUCKET_NAME}" \
    --region "${AWS_REGION}" \
    --delete \
    --cache-control "public, max-age=3600" \
    --exclude ".git/*" \
    --exclude ".gitignore" \
    --exclude "README.md" \
    --exclude "*.sh"

if [ $? -ne 0 ]; then
    echo -e "${RED}Deployment to S3 failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Deployed to S3${NC}"
echo ""

# Invalidate CloudFront cache if distribution ID is set
if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo -e "${BLUE}Invalidating CloudFront cache...${NC}"
    INVALIDATION_ID=$(aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "/*" \
        --query 'Invalidation.Id' \
        --output text)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ CloudFront invalidation created: ${INVALIDATION_ID}${NC}"
        echo "  (Cache will be cleared in a few minutes)"
    else
        echo -e "${RED}Warning: CloudFront invalidation failed${NC}"
    fi
    echo ""
fi

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your site is now live at:"
if [ ! -z "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
    echo -e "  ${BLUE}https://${BUCKET_NAME}${NC}"
else
    echo -e "  ${BLUE}http://${BUCKET_NAME}.s3-website-${AWS_REGION}.amazonaws.com${NC}"
    echo ""
    echo "To enable HTTPS and custom domain:"
    echo "  1. Set up CloudFront distribution"
    echo "  2. Configure Route 53 or your DNS provider"
    echo "  3. Set CLOUDFRONT_DISTRIBUTION_ID environment variable"
fi
echo ""
