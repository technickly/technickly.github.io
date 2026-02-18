# Quick Start Guide

Get your Opsis website live in 3 steps.

## Step 1: Test Locally

```bash
# Install dependencies
bundle install

# Run local server
bundle exec jekyll serve

# View at http://localhost:4000
```

## Step 2: Deploy to S3

```bash
# Create S3 bucket
aws s3 mb s3://technickly.ai

# Enable static website hosting
aws s3 website s3://technickly.ai \
  --index-document index.html \
  --error-document 404.html

# Set bucket policy (make public)
cp bucket-policy.json.example bucket-policy.json
aws s3api put-bucket-policy \
  --bucket technickly.ai \
  --policy file://bucket-policy.json

# Deploy!
./deploy.sh
```

Your site is now live at: `http://technickly.ai.s3-website-us-east-1.amazonaws.com`

## Step 3: Add HTTPS + Custom Domain (Optional but Recommended)

### 3a. Create CloudFront Distribution

1. Go to AWS Console → CloudFront
2. Create Distribution
3. Origin Domain: `technickly.ai.s3-website-us-east-1.amazonaws.com`
4. Alternate Domain Names: `technickly.ai`, `www.technickly.ai`
5. Request SSL Certificate (ACM) for `technickly.ai`
6. Wait ~15 minutes for deployment

### 3b. Configure DNS

**Option 1: Route 53** (Recommended)

```bash
# Create hosted zone
aws route53 create-hosted-zone \
  --name technickly.ai \
  --caller-reference $(date +%s)

# Create DNS records
cp dns-records.json.example dns-records.json
# Edit dns-records.json with your CloudFront domain
aws route53 change-resource-record-sets \
  --hosted-zone-id YOUR_ZONE_ID \
  --change-batch file://dns-records.json

# Update domain nameservers to Route 53's NS records
```

**Option 2: Your Domain Registrar**

In your domain registrar's DNS settings:
- Add CNAME: `@` → `YOUR_DISTRIBUTION.cloudfront.net`
- Add CNAME: `www` → `YOUR_DISTRIBUTION.cloudfront.net`

### 3c. Deploy with CloudFront Invalidation

```bash
# Set your distribution ID
export CLOUDFRONT_DISTRIBUTION_ID=YOUR_DIST_ID

# Deploy (will automatically invalidate cache)
./deploy.sh
```

## Done! 

Your site is now live at `https://technickly.ai`

## Common Commands

```bash
# Local development
bundle exec jekyll serve

# Build only
bundle exec jekyll build

# Deploy to S3
./deploy.sh

# Deploy with CloudFront invalidation
CLOUDFRONT_DISTRIBUTION_ID=YOUR_ID ./deploy.sh
```

## Troubleshooting

**Site not showing new changes?**
- CloudFront cache takes ~5 minutes to invalidate
- Clear browser cache

**Permission denied on deploy.sh?**
```bash
chmod +x deploy.sh
```

**AWS credentials not configured?**
```bash
aws configure
```

**Ruby/bundle issues?**
```bash
gem install bundler
bundle install
```

## Next Steps

- Customize content in markdown files
- Add your own images to `assets/images/`
- Update `_config.yml` with your info
- Set up GitHub Actions for auto-deployment (see README)

For detailed documentation, see [README.md](README.md)
