import json
import boto3
import base64
import urllib3
import logging
import os

url = os.environ.get('NOTIFICATION_API_URL')
api_key = os.environ.get('NOTIFICATION_API_KEY')
slack_channel = os.environ.get('SLACK_CHANNEL', 'au-platform-alerts')

logger = logging.getLogger()
level = logging.getLevelName(os.environ.get('LOG_LEVEL', 'INFO'))
logger.setLevel(level)

backup = boto3.client('backup')
ec2 = boto3.client('ec2')
rds = boto3.client('rds')
dynamo = boto3.client('dynamodb')
efs = boto3.client('efs')


def notify(payload):
    http = urllib3.PoolManager()
    headers= {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + api_key}
    encoded_data = json.dumps(payload).encode('utf-8')
    try:
        response = http.request('POST',url,body=encoded_data,headers=headers)
    except Exception as e:
        logger.error(str(e))
    else:
        response_data = response.data.decode()
        logger.info(f'Response is {response_data}')


def job_failed(title, message):
    title = title
    channel = slack_channel
    type = "error"
    message = message
    payload = {
        "message": message,
        "type": type,
        "title": title,
        "channel": channel,
    }
    notify(payload)


def check_tag(resource_type, resource_arn, this_key, this_value):
    if resource_type in ["RDS", "Aurora"]:
        response = rds.list_tags_for_resource(
            ResourceName = resource_arn
        )
        tag_list = response.get('TagList')
        for tag in tag_list:
            key = tag.get('Key')
            value = tag.get('Value')
            if key == this_key and value == this_value:
                return True
    elif resource_type == "EC2":
        instance_id = resource_arn.split("/")[-1]
        response = ec2.describe_tags(
            Filters=[
                {
                    'Name': 'resource-id',
                    'Values': [
                        instance_id,
                    ],
                },
            ],
        )
        tag_list = response.get('Tags')
        for tag in tag_list:
            key = tag.get('Key')
            value = tag.get('Value')
            if key == this_key and value == this_value:
                return True
    return False


def check_restore_enabled(resource_type, resource_arn):
    return check_tag(resource_type, resource_arn, "restore", "enabled")


def check_restore_optimised(resource_type, resource_arn):
    return check_tag(resource_type, resource_arn, "restore-optimised", "true")


def backup_job_success(backup_job_id):
    backup_info = backup.describe_backup_job(BackupJobId = backup_job_id)
    #get backup job details
    recovery_point_arn = backup_info['RecoveryPointArn']
    iam_role_arn = backup_info['IamRoleArn']
    backup_vault_name = backup_info['BackupVaultName']
    resource_type = backup_info['ResourceType']
    resource_arn = backup_info['ResourceArn']

    restore_enabled = check_restore_enabled(resource_type, resource_arn)
    if restore_enabled is True:
        logger.info(f"In backup_job_success. Resource type is {resource_type}. Resource ARN is {resource_arn}")
    else:
        logger.info(f"Restore is not enabled for this resource - {resource_type} {resource_arn}")
        return True

    metadata = backup.get_recovery_point_restore_metadata(
        BackupVaultName=backup_vault_name,
        RecoveryPointArn=recovery_point_arn
    )

    #determine resource type that was backed up and get corresponding metadata
    if resource_type == 'DynamoDB':
        metadata['RestoreMetadata']['targetTableName'] = metadata['RestoreMetadata']['originalTableName'] + '-restore-test'
    elif resource_type == 'EBS':
        volumeid = resource_arn.split("/")[1]

        metadata['RestoreMetadata']['availabilityZone'] = ec2.describe_volumes(
        VolumeIds=[
            volumeid
        ]
        )['Volumes'][0]['AvailabilityZone']
    elif resource_type == 'RDS':
        metadata['RestoreMetadata']['DBInstanceIdentifier'] = resource_arn.split("/")[1] + '-restore-test'
    elif resource_type == 'Aurora':
        metadata['RestoreMetadata']['DBClusterIdentifier'] = resource_arn.split(":")[-1] + '-restore-test'
    elif resource_type == 'EFS':
        metadata['RestoreMetadata']['PerformanceMode'] = 'generalPurpose'
        metadata['RestoreMetadata']['newFileSystem'] = 'true'
        metadata['RestoreMetadata']['Encrypted'] = 'false'
        metadata['RestoreMetadata']['CreationToken'] = metadata['RestoreMetadata']['file-system-id'] + '-restore-test'
    elif resource_type == 'EC2':
        metadata['RestoreMetadata']['CpuOptions'] = '{}'
        metadata['RestoreMetadata']['NetworkInterfaces'] = '[]'
        restore_optimised = check_restore_optimised(resource_type, resource_arn)
        if restore_optimised is True:
            metadata['RestoreMetadata']['InstanceType'] = "t3.micro"
    elif resource_type == 'S3':
        logger.info("S3 restore is not supported yet.")

    #API call to start the restore job
    logger.info('Starting the restore job')
    logger.info(f"Metadata is {metadata}")
    restore_request = backup.start_restore_job(
            RecoveryPointArn=recovery_point_arn,
            IamRoleArn=iam_role_arn,
            Metadata=metadata['RestoreMetadata']
    )

    logger.info(json.dumps(restore_request))


def restore_job_success(restore_job_id):
    restore_info = backup.describe_restore_job(RestoreJobId=restore_job_id)
    resource_type = restore_info['ResourceType']

    logger.info('Restore from the backup was successful. Deleting the newly created resource.')

    #determine resource type that was restored and delete it to save cost
    if resource_type == 'DynamoDB':
        table_name = restore_info['CreatedResourceArn'].split(':')[5].split('/')[1]

        # Include recovery validation checks for DynamoDB here

        logger.info(f'Deleting: {table_name}')
        delete_request = dynamo.delete_table(
                            TableName=table_name
                        )
    elif resource_type == 'EC2':
        ec2_resource_type = restore_info['CreatedResourceArn'].split(':')[5].split('/')[0]
        if ec2_resource_type == 'volume':
            volume_id = restore_info['CreatedResourceArn'].split(':')[5].split('/')[1]

            # Include recovery validation checks for EBS here

            logger.info(f'Deleting: {volume_id}')
            delete_request = ec2.delete_volume(
                        VolumeId=volume_id
                    )
        elif ec2_resource_type == 'instance':
            instance_id = restore_info['CreatedResourceArn'].split(':')[5].split('/')[1]

            logger.info(f'Deleting: {instance_id}')
            delete_request = ec2.terminate_instances(
                        InstanceIds=[
                            instance_id
                        ]
                    )
            message = 'Restore from ' + restore_info['RecoveryPointArn'] + ' was successful. Data recovery validation succeeded. ' + 'The newly created resource ' + restore_info['CreatedResourceArn'] + ' has been cleaned up.'

            #logger.info('Validating data recovery before deletion.')
            ##validating data recovery
            #instance_details = ec2.describe_instances(
            #            InstanceIds=[
            #                instance_id
            #            ]
            #        )
            #public_ip = instance_details['Reservations'][0]['Instances'][0]['PublicIpAddress']
            #
            #http = urllib3.PoolManager()
            #url = public_ip
            #try:
            #    resp = http.request('GET', url)
            #    logger.info("Received response:")
            #    logger.info(resp.status)
            #
            #    if resp.status == 200:
            #        logger.info('Valid response received. Data recovery validated. Proceeding with deletion.')
            #        logger.info(f'Deleting: {instance_id}')
            #        delete_request = ec2.terminate_instances(
            #                    InstanceIds=[
            #                        instance_id
            #                    ]
            #                )
            #        message = 'Restore from ' + restore_info['RecoveryPointArn'] + ' was successful. Data recovery validation succeeded with HTTP ' + str(resp.status) + ' returned by the application. ' + 'The newly created resource ' + restore_info['CreatedResourceArn'] + ' has been cleaned up.'
            #    else:
            #        logger.error('Invalid response. Validation FAILED.')
            #        message = 'Invalid response received: HTTP ' + str(resp.status) + '. Data Validation FAILED. New resource ' + restore_info['CreatedResourceArn'] + ' has NOT been cleaned up.'
            #except Exception as e:
            #    logger.error(str(e))
            #    message = 'Error connecting to the application: ' + str(e)
    elif resource_type == 'RDS':
        database_identifier = restore_info['CreatedResourceArn'].split(':')[6]
        logger.info(f"In restore_job_success. DB instance ID is {database_identifier}")
        # Include recovery validation checks for RDS here

        logger.info(f'Deleting: {database_identifier}')
        delete_request = rds.delete_db_instance(
                    DBInstanceIdentifier=database_identifier,
                    SkipFinalSnapshot=True
                )
    elif resource_type == 'Aurora':
        database_cluster_identifier = restore_info['CreatedResourceArn'].split(':')[6]
        logger.info(f"In restore_job_success. DB Cluster ID is {database_cluster_identifier}")
        # Include recovery validation checks for Aurora here

        logger.info(f'Deleting: {database_cluster_identifier}')
        delete_request = rds.delete_db_cluster(
                    DBClusterIdentifier=database_cluster_identifier,
                    SkipFinalSnapshot=True
                )
    elif resource_type == 'EFS':
        elastic_file_system = restore_info['CreatedResourceArn'].split(':')[5].split('/')[1]

        # Include recovery validation checks for EFS here

        logger.info(f'Deleting: {elastic_file_system}')
        delete_request = efs.delete_file_system(
                    FileSystemId=elastic_file_system
                )
    logger.info(f"Test restore resource deleted.")


def handler(event, context):
    logger.info(event)
    account_id = event.get('account')
    region = event.get('region')
    state = event.get('detail').get('state') or event.get('detail').get('status')
    backup_job_id = event.get('detail').get('backupJobId')
    restore_job_id = event.get('detail').get('restoreJobId')
    copy_job_id = event.get('detail').get('copyJobId')
    if backup_job_id is not None and state == "COMPLETED":
        logger.info(f"Backup job {state} {backup_job_id}")
        backup_job_success(backup_job_id)
    elif restore_job_id is not None and state == "COMPLETED":
        logger.info(f"Restore job {state} {restore_job_id}")
        restore_job_success(restore_job_id)
    elif backup_job_id is not None and state in ["FAILED", "ABORTED", "EXPIRED"]:
        logger.info(f"Backup job {state} {backup_job_id}")
        backup_info = backup.describe_backup_job(BackupJobId = backup_job_id)
        resource_arn = backup_info['ResourceArn']
        title = "Backup Job " + state
        message = "Backup " + state + " for resource " + resource_arn
        job_failed(title, message)
    elif restore_job_id is not None and state in ["FAILED", "ABORTED", "EXPIRED"]:
        logger.info(f"Restore job {state} {restore_job_id}")
        restore_info = backup.describe_restore_job(RestoreJobId=restore_job_id)
        title = "Restore Job " + state
        message = "Restoring backup " + state + " for restore job " + restore_job_id
        job_failed(title, message)