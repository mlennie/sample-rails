class Postgres

  DB_HOST = ENV['DB_HOSTNAME']
  DB_PORT = ENV['DB_PORT']
  DB_USER = ENV['DB_USER']
  DB_NAME = ENV['DB_NAME']
  DB_PASSWORD= ENV['DB_PASSWORD']
  BUCKET_NAME=ENV['B2_BUCKET_NAME']

  def self.backup
    Rails.logger.info "Dumping database"
    system "PGPASSWORD=#{DB_PASSWORD} \
            pg_dump \
            -h #{DB_HOST} \
            -p #{DB_PORT} \
            -U #{DB_USER} \
            -Ft \
            -d #{DB_NAME} \
            | gzip > backup_#{Rails.env}.tar.gz"
    Rails.logger.info "Done!"
  end

  def self.push_backup_to_b2
    Rails.logger.info "Pushing postgres backup to B2"

    file = "backup_#{Rails.env}.tar.gz"

    unless File.exist?(file)
      Rails.logger.error "Postgres backup file with path #{file} doesn't exist"
      return
    end

    content_type =  "application/x-gzip"

    bucket_id = B2::POSTGRES_BUCKET_ID
    response = B2.upload_file(bucket_id, file, content_type)
    sha1 = Digest::SHA1.hexdigest(File.read(file))

    if response[:contentSha1] === sha1
      Rails.logger.info "Removing backup gzip file"
      system "rm backup_#{Rails.env}.tar.gz"
      Rails.logger.info "Done!"
    else
      Rails.logger.error "Error pushing postgres backup to B2"
    end
  end

  def self.pull_backup_from_b2
    Rails.logger.info "Pulling postgres backup from B2"

    bucket_name = BUCKET_NAME
    file_name = "backup_#{Rails.env}"
    response = B2.download_file_by_name bucket_name, file_name

    if response && response[:body].present?
      File.open("backup_#{Rails.env}.tar.gz", "wb+") do |f|
        f.binmode
        f.write(response[:body])
      end
      Rails.logger.info "Done!"
    else
      Rails.logger.error "Error pulling postgres backup from B2"
    end
  end

  def self.restore
    Rails.logger.info "Uncompressing gzip file"

    unless File.exist?("backup_#{Rails.env}.tar.gz")
      Rails.logger.error "No backup file to restore"
      return
    end

    system "gzip -d backup_#{Rails.env}.tar.gz"

    Rails.logger.info "Restoring database"
    system "PGPASSWORD=#{DB_PASSWORD} \
            pg_restore \
            -h #{DB_HOST} \
            -p #{DB_PORT} \
            -U #{DB_USER} \
            -d #{DB_NAME} \
            backup_#{Rails.env}.tar"
    Rails.logger.info "Removing backup file"
    system "rm backup_#{Rails.env}.tar"

    Rails.logger.info "Done!"
  end

  def self.backup_and_push_to_b2
    self.backup
    self.push_backup_to_b2
  end

  def self.pull_from_b2_and_restore
    self.pull_backup_from_b2
    self.restore
  end
end
