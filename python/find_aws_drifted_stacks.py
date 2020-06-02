#!/usr/bin/env python3
import json
import time
import boto3

CLOUDFORMATION_CLIENT = boto3.client('cloudformation')

def get_stack_names():
    print("Collecting list of stack names...")
    stacks = CLOUDFORMATION_CLIENT.list_stacks(
        StackStatusFilter=[
            'CREATE_COMPLETE',
            'ROLLBACK_COMPLETE',
            'UPDATE_COMPLETE',
            'ROLLBACK_FAILED',
            'DELETE_FAILED',
            'UPDATE_ROLLBACK_FAILED',
            'UPDATE_ROLLBACK_COMPLETE',
            'IMPORT_COMPLETE',
            'IMPORT_ROLLBACK_FAILED',
            'IMPORT_ROLLBACK_COMPLETE'
        ]
    )

    stack_names = []
    for summary in stacks['StackSummaries']:
        stack_names.append(summary['StackName'])

    return stack_names

def start_drift_detection(stack_names):
    stack_drift_detection_ids = []

    for stack_name in stack_names:
        print("Starting drift detection for {}".format(stack_name))
        detect_stack_drift_response = CLOUDFORMATION_CLIENT.detect_stack_drift(
            StackName=stack_name
        )
        stack_drift_detection_ids.append(detect_stack_drift_response['StackDriftDetectionId'])

    return stack_drift_detection_ids

def wait_for_stack_detection(stack_drift_detection_ids):
    detection_in_progress = True
    stack_statuses = []

    while detection_in_progress and stack_drift_detection_ids:
        time.sleep(5)
        for detection_id in stack_drift_detection_ids:
            detection_in_progress = False

            detection_status = CLOUDFORMATION_CLIENT.describe_stack_drift_detection_status(
                StackDriftDetectionId=detection_id
            )

            if detection_status['DetectionStatus'] == 'DETECTION_IN_PROGRESS':
                print("drift detection still in progress for {}".format(detection_id))
                detection_in_progress = True
                stack_statuses = []
                break

            stack_statuses.append(detection_status)

    return stack_statuses

def all_stacks_in_sync(stack_statuses):
    for status in stack_statuses:
        if status['StackDriftStatus'] != 'IN_SYNC':
            return False
    return True

def get_drifted_resources(stack_names):
    drifted_resources = {}

    for stack_name in stack_names:
        print("getting out of sync resources for {}".format(stack_name))
        stack_drifted_resources = CLOUDFORMATION_CLIENT.describe_stack_resource_drifts(
            StackName=stack_name,
            StackResourceDriftStatusFilters=[
                'MODIFIED',
                'DELETED'
            ]
        )
        drifted_resources[stack_name] = stack_drifted_resources['StackResourceDrifts']

    return drifted_resources

def main():
    stack_names = get_stack_names()
    stack_drift_detection_ids = start_drift_detection(stack_names)
    stack_statuses = wait_for_stack_detection(stack_drift_detection_ids)

    if not all_stacks_in_sync(stack_statuses):
        drifted_resources = get_drifted_resources(stack_names)
        print(json.dumps(drifted_resources, indent=4, default=str))
    else:
        print('No stacks have drifted')

if __name__ == '__main__':
    main()
