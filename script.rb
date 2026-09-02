require 'aws-sdk-s3'
require 'aws-sdk-cloudwatch'
require 'date'
require 'open3'

DATABASES_TO_BACKUP  = (ENV["DATABASE_NAMES"] || "").split(",")
BACKUP_BUCKET        = ENV['S3_BUCKET_NAME']
BACKUP_BUCKET_REGION = ENV['S3_REGION']
SLEEP_INTERVAL       = (ENV['SLEEP_INTERVAL'] || 1800).to_i
MIN_BACKUP_BYTES     = (ENV['MIN_BACKUP_BYTES'] || 1024).to_i
METRIC_NAMESPACE     = ENV['CLOUDWATCH_METRIC_NAMESPACE']
METRIC_TIMESTAMP_UTC = ENV.fetch('METRIC_TIMESTAMP_UTC', '12:00')

class SendToLog
  def self.call(msg)
    Logger.new('/proc/1/fd/1').info(msg)
  end
end

class BackupProcess
  def initialize(db_name, connection_params)
    @db_name = db_name
    @connection_params = connection_params
    @backup_filename = "#{DateTime.now}_#{db_name}"
  end

  def call
    SendToLog.call("Commencing backing up #{@db_name}")
    pg_dump
    verify_backup
    upload_to_s3
    publish_metric
  ensure
    delete_backup
  end

  private

  def pg_dump
    `echo *:*:*:*:#{@connection_params.password} > ~/.pgpass && chmod 0600 ~/.pgpass`
    SendToLog.call('Running pg_dump')
    _stdout, stderr, status = Open3.capture3(
      'pg_dump', '-Fc', '-O', '-x',
      '-h', @connection_params.host, '-d', @db_name,
      '-f', @backup_filename, '-U', @connection_params.username
    )
    raise "pg_dump failed for #{@db_name} (#{status}) - #{stderr}" unless status.success?
    SendToLog.call('pg_dump complete')
  end

  def verify_backup
    @backup_bytes = File.exist?(@backup_filename) ? File.size(@backup_filename) : 0
    if @backup_bytes < MIN_BACKUP_BYTES
      raise "backup of #{@db_name} is #{@backup_bytes} bytes (expected at least #{MIN_BACKUP_BYTES}) - refusing to upload it"
    end

    _stdout, stderr, status = Open3.capture3('pg_restore', '--list', @backup_filename)
    raise "backup of #{@db_name} is unreadable by pg_restore - #{stderr}" unless status.success?
  end

  def upload_to_s3
    SendToLog.call('Uploading backup to S3')
    s3 = Aws::S3::Resource.new(region: BACKUP_BUCKET_REGION)
    s3_key_path = @db_name + '/' + @backup_filename
    obj = s3.bucket(BACKUP_BUCKET).object(s3_key_path)
    obj.upload_file(@backup_filename)
    @backup_bytes = obj.content_length
  end

  def publish_metric
    return if METRIC_NAMESPACE.nil?

    timestamp = metric_timestamp
    cloudwatch = Aws::CloudWatch::Client.new(region: BACKUP_BUCKET_REGION)
    cloudwatch.put_metric_data(
      namespace: METRIC_NAMESPACE,
      metric_data: [{
        metric_name: 'BackupBytes',
        dimensions: [{ name: 'Database', value: @db_name }],
        unit: 'Bytes',
        value: @backup_bytes,
        timestamp: timestamp
      }]
    )
    SendToLog.call("Published BackupBytes metric stamped #{timestamp}")
  rescue StandardError => e
    SendToLog.call("Metric publish failed for #{@db_name} (backup already uploaded) - #{e}")
  end

  def metric_timestamp
    hour, minute = METRIC_TIMESTAMP_UTC.split(':').map(&:to_i)
    today = Time.now.utc
    Time.utc(today.year, today.month, today.day, hour, minute)
  end

  def delete_backup
    return unless File.exist?(@backup_filename)

    SendToLog.call('Deleting backup')
    File.delete(@backup_filename)
  end
end

class ValidateParams
  def self.call
    raise 'MISSING PARAMS' if
      DATABASES_TO_BACKUP.length == 0 ||
      BACKUP_BUCKET.nil? ||
      BACKUP_BUCKET_REGION.nil?
  end
end

ValidateParams.call

loop do
  SendToLog.call('Commencing Run')

  DATABASES_TO_BACKUP.each do |db_name|
    begin
      connection_params = OpenStruct.new(
		      host: ENV["#{db_name}_host"],
		      username: ENV["#{db_name}_username"],
		      password: ENV["#{db_name}_password"]
      )
      BackupProcess.new(db_name, connection_params).call
    rescue StandardError => e
      SendToLog.call("Error when backing up #{db_name} - #{e}")
      next
    ensure
      connection_params = nil
    end
  end

  SendToLog.call("Completed Run. Next run in #{SLEEP_INTERVAL} seconds")
  sleep SLEEP_INTERVAL
end
