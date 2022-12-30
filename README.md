# Automated Backup and Restore Solution

<img width="1357" alt="image" src="https://user-images.githubusercontent.com/48516472/210050432-24e00f74-901e-4727-8d02-9847c146f743.png">

## How It Works
- Create Backup plans to define the schedule, retention policy and targets (protected resources).
- Targets are selected using tag based approach. Each backup plan has its distinct associated tag. To backup a resource, we simply add a tag to that resource corresponding to the backup plan of choice.
- AWS Backup performs the backup activities according to the schedule defined in the backup plan.
- When the Backup job completes, an event triggers a Lambda function which starts a restore job and subsequently creates a test resource from the backup.
- When the Restore job completes, an event triggers a Lambda function which cleans up the test resource.
- When the Backup or Restore job fails, an event triggers a Lambda function which sends a notification to a slack channel.

| Name | Description | Schedule | Retention | Resource | Backup Tags | Restore Tags |
| --- | --- | --- | --- | --- | --- | --- |
| daily-ec2 | Generic backup plan for EC2 instances | Daily at 10 PM | 7 days | EC2 instance | backup-schedule=daily-ec2 | restore=enabled |
| daily-rds | Generic backup plan for RDS Aurora clusters | Daily at 12 AM | Production: 30 days, NonProd: 7 days | Aurora cluster | backup-schedule=daily-rds | restore=enabled |
| daily-s3 | Generic backup plan for S3 buckets | Daily at 1 AM | 30 days | S3 bucket | backup-schedule=daily-s3 | restore=enabled |
