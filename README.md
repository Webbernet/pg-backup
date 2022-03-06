## Webbernet PG Backup tool

### Why 
We need a way to backup a Postgres database to S3 so that we can ship the backups offsite

### Setup

* You will need to setup an S3 bucket, and give this script PutObject permissions to it
* You will need to have credentials for your database

### Creating a backup user

It's recommended to create a seperate user that the script can use for backups. Follow the following steps to set this up

$ CREATE USER backupuser; 

// Connect to your database you wish to give access to
$ ALTER DEFAULT PRIVILEGES in schema public grant select on sequences to backupuser;
$ ALTER DEFAULT PRIVILEGES in schema public grant select on tables to backupuser;
$ GRANT SELECT ON ALL TABLES IN SCHEMA public TO backupuser;

## Running

You will need a few parameters

```
docker run \
-e DATABASE_NAMES=some_database
-e S3_BUCKET_NAME=my-backups-bucket
-e S3_REGION=ap-southeast-2
-e some_database_host=host-some-database.rds.com
-e some_database_user=backupuser
-e password=foobar
webbernet/pg-backup 

```

### Params

| Name | Required | |
| ------------- |-------------| -----|
| DATABASE_NAMES  | Yes | Comma delimited string of all the databases you wish to backup |
| S3_BUCKET_NAME | Yes | S3 bucket name where you wish to store the backups |
| S3_REGION  | Yes | AWS Region |
| SLEEP_INTERVAL | - | How often to backup each database. Default 1800 seconds |
| <DATABASE_NAME>_host | Yes | Database host |
| <DATABASE_NAME>_username | Yes | Database username |
| <DATABASE_NAME>_password | Yes | Database password |

*Note* You need to provide a host, username and password for every database you specify in the `DATABASE_NAMES` parameter.
