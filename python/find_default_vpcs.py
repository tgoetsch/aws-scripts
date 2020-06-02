#!/usr/bin/env python3
import boto3

def get_ec2_regions():
    client = boto3.client('ec2')
    return client.describe_regions()['Regions']

def get_region_default_vpc(region_name):
    client = boto3.client('ec2', region_name = region_name)
    vpc_filter = [
        {
            'Name': 'isDefault',
            'Values': ['true']
        }
    ]
    defaultVpc = client.describe_vpcs(Filters=vpc_filter)['Vpcs']
    return defaultVpc[0] if len(defaultVpc) == 1 else None

def main():
    regions = get_ec2_regions()

    for region in regions:
        vpc = get_region_default_vpc(region['RegionName'])
        if vpc:
            print(region['RegionName'] + '\tHas Default PVC')
        else:
            print(region['RegionName'] + '\tWOO HOO, CLEAN!')

if __name__ == '__main__':
    main()
