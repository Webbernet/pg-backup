# Webbernet PG Backup tool

This tool allows to backup a set of Postgres databases on a recurring schedule. This script is designed to be always running.

The script will backup each Postgres database via pg_dump and upload it to an S3 bucket.

### Setup

* You will need to setup an S3 bucket, and give this script PutObject permissions to it
* You will need to have credentials for your database

### Creating a backup user

It's recommended to create a seperate Postgres user that the script can use for backups. Follow the following steps to set this up

```
CREATE USER backupuser WITH PASSWORD 'foobar'; 

ALTER DEFAULT PRIVILEGES in schema public grant select, usage on sequences to backupuser;
ALTER DEFAULT PRIVILEGES in schema public grant select on tables to backupuser;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO backupuser;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO backupuser;
```

## Running

You can run the script with the following docker command

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

**Note** You need to provide a host, username and password for every database you specify in the `DATABASE_NAMES` parameter.


THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


