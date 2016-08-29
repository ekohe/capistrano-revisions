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
        create_revisions_history_file
        send_email
        create_revisions_history_xml_file
        create_redmine_wiki_from_xml_file
      end
    end

    def create_revisions_history_file
      revision = capture "cat #{current_path}/REVISION"
      run_locally do
        begin
          git_log = capture "git log #{revision}..#{fetch(:cr_branch)} --pretty=format:'%ad %an %h  %s' --date=short"
        rescue
          puts "INFO: No commits to deploy"
          exit
        end
        set :git_log, git_log
      end
      execute "[[ -f #{TXT_FILE_PATH} ]] || echo -e '#{fetch(:cr_env).capitalize} deployment history' > #{TXT_FILE_PATH}"
      execute "echo '#{Time.now.strftime('%d-%m-%Y')}' >> #{TXT_FILE_PATH}"
      fetch(:git_log).split("\n").each do |commit|
        execute "echo -e \"#{commit}\" >> #{TXT_FILE_PATH}"
      end
    end

    def send_email
      create_email_file
      execute "cat #{EMAIL_FILE_PATH} | mail -a 'Content-type: text/html;' -s 'Deployment Notifier: #{fetch(:application)} has just been deployed to #{fetch(:cr_env)} server' #{fetch(:cr_email)}"
    end

    def create_email_file
      revisions_email = File.open(EMAIL_TMP_FILE_PATH,'w')
      revisions_email.truncate(0)
      revisions_email.write("<p>Environment: #{fetch(:cr_env)}</p>")
      revisions_email.write("Commits in this deployment:<ol>")
      fetch(:git_log).each_line do |line|
        revisions_email.write("<li>#{line}</li>")
      end
      revisions_email.write("</ol>")
      revisions_email.write("Full deployment <a href=\"#{fetch(:cr_redmine_url).gsub('.xml','')}\">history</a>")
      revisions_email.close
      upload! EMAIL_TMP_FILE_PATH, EMAIL_FILE_PATH
    end

    def create_revisions_history_xml_file
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
          revisions_xml.write("# #{line}")
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
  end
end

