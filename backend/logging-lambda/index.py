import json
import boto3

dynamodb = boto3.resource('dynamodb')
destination_table = dynamodb.Table('terraform_audit_table')

def lambda_handler(event, context):
    print(event)
    for record in event['Records']:
        if record['eventName'] == 'INSERT':
            new_run = record['dynamodb']['NewImage']
            info = new_run.get('Info', {}).get('S')
            print(info)
            if info:
                destination_table.put_item(
                    Item={
                        'LockID': new_run['LockID']['S'],
                        'info': info
                    }
                )
    return {
        'statusCode': 200,
        'body': json.dumps('Success')
    }
