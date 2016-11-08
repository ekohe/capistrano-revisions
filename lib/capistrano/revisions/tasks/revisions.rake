namespace :deploy do
  desc <<-DESC
    Track and notify about changes to deployment history
  DESC
  task :revisions => "deploy:revisions:create"

  namespace :revisions do
    task :create do
      on roles(:web) do |host|
        TXT_FILE_PATH = "#{shared_path}/log/revisions_#{fetch(:cr_env)}.txt"
        XML_FILE_PATH = "#{shared_path}/log/revisions_#{fetch(:cr_env)}.xml"
        XML_TMP_FILE_PATH = "tmp/revisions_#{fetch(:cr_env)}.xml"
        EMAIL_FILE_PATH = "#{shared_path}/log/revisions_email_#{fetch(:cr_env)}.html"
        EMAIL_TMP_FILE_PATH = "tmp/revisions_email_#{fetch(:cr_env)}.html"
        HISTORY_PATH = "#{shared_path}/log/revisions_#{fetch(:cr_env)}.yml"

        begin
          prepare_deployment_info
          create_structured_deployment_history
          create_revisions_history_file
          send_email
          create_revisions_history_xml_file
          create_redmine_wiki_from_xml_file
        rescue Exception => e
          puts 'FATAL: failed to create revision notification'
          puts e.message
        end
      end
    end

    def create_revisions_history_file
      execute "[[ -f #{TXT_FILE_PATH} ]] || echo -e '#{fetch(:cr_env).capitalize} deployment history' > #{TXT_FILE_PATH}"
      execute "echo '#{Time.now.strftime('%d-%m-%Y')}' >> #{TXT_FILE_PATH}"
      execute "echo '' >> #{TXT_FILE_PATH}"

      fetch(:deploy_log).each do |msg|
        execute "echo -e \"#{msg}\" >> #{TXT_FILE_PATH}"
      end
    end

    def send_email
      create_email_file
      execute "cat #{EMAIL_FILE_PATH} | mail -a 'Content-type: text/html;' -s 'Deployment Notifier: #{fetch(:application)} has just been deployed to #{fetch(:cr_env)} server' #{fetch(:cr_email)}"
    end

    def create_email_file
      execute 'mkdir -p tmp'
      revisions_email = File.open(EMAIL_TMP_FILE_PATH,'w')
      revisions_email.truncate(0)
      revisions_email.write("<p>Environment: #{fetch(:cr_env)}</p>")
      revisions_email.write("Commits in this deployment:<ol>")
      fetch(:deploy_log).each do |line|
        revisions_email.write("<li>#{line}</li>")
      end
      revisions_email.write("</ol>")
      revisions_email.write("Full deployment <a href=\"#{fetch(:cr_redmine_url).gsub('.xml','')}\">history</a>")
      revisions_email.close
      upload! EMAIL_TMP_FILE_PATH, EMAIL_FILE_PATH
    end

    def create_revisions_history_xml_file
      execute 'mkdir -p tmp'
      revisions_xml = File.open(XML_TMP_FILE_PATH,'w')
      revisions_xml.truncate(0)
      revisions_xml.write("<?xml version='1.0'?>\n")
      revisions_xml.write("<wiki_page>\n")
      revisions_xml.write("<text>\n")
      capture("cat #{TXT_FILE_PATH}").each_line do |line|
        if line.match(/.*deployment history$/)
          revisions_xml.write("h1. #{line} \n")
        elsif line.match(/^\d{2}-\d{2}-\d{4}$/)
          revisions_xml.write("\n")
          revisions_xml.write("h2. #{line} \n")
        else
          revisions_xml.write("# #{line.gsub('&','&#038;')}")
        end
      end
      revisions_xml.write("</text>\n")
      revisions_xml.write("</wiki_page>")
      revisions_xml.close
      upload! XML_TMP_FILE_PATH, XML_FILE_PATH
    end

    def create_redmine_wiki_from_xml_file
        execute "curl -s -H 'Content-Type: application/xml' -X PUT --data-binary '@#{XML_FILE_PATH}' -H 'X-Redmine-API-Key: #{fetch(:cr_redmine_key)}' #{fetch(:cr_redmine_url)}"
    end

    #
    # to be used for front-end presentation
    #
    def create_structured_deployment_history
      execute "[[ -f #{HISTORY_PATH} ]] || echo -e '---' > #{HISTORY_PATH}"
      execute "echo '#{Time.now.to_s}:' >> #{HISTORY_PATH}"

      fetch(:deploy_log).each do |msg|
        execute <<-CMD
          echo "  - \'#{msg.gsub(/['"`]/, '')}\'" >> #{HISTORY_PATH}
        CMD
      end
    end

    def _awesome(sha1, sha2)
      base = `git merge-base #{sha1} #{sha2}`.chomp

      if base.start_with?(sha1)
        action = 'deployed'
        commits_range = [sha1, sha2].join('..')
      elsif base.start_with?(sha2)
        action = 'reverted'
        commits_range = [sha2, sha1].join('..')
      else
        # NOTE: This should not happen cause you MUST have a common ancestor
        # when deploy new stuff to the server but anyway
        action = 'YOUR BRANCH IS DIVERGED'
        commits_range = 'HEAD..HEAD'
      end

      [action, commits_range]
    end

    def prepare_deployment_info
      last_release = capture "ls -t1 #{releases_path} | head -1"
      last_revision = capture "cat #{releases_path}/#{last_release}/REVISION"
      current_revision = fetch(:branch)
      action, commits_range = _awesome(last_revision, current_revision)

      run_locally do
        raw_log = capture("git log #{commits_range} --no-merges --pretty=format:'%s'")
        deploy_log = raw_log.split("\n").map { |l| l.gsub(/['"`]/, '') }
        deploy_description = "#{action} #{deploy_log.size} commit(s)"

        set :deploy_log, deploy_log.unshift(deploy_description)
      end
    end
  end
end

