namespace :deploy do

  desc <<-DESC
    1. Creates a Redmine Wiki page which displays the commits since your last deploy.
    2. Notifies via email of commits since your last deploy.
  DESC
  task :revisions => "deploy:revisions:create"

  namespace :revisions do
    task :create do
      on roles(:web) do |host|
        create_revisions_history_file
        send_email
        create_revisions_history_xml_file
        create_redmine_wiki_from_xml_file
      end
    end

    def create_revisions_history_file
      revision = capture "cat #{current_path}/REVISION"
      run_locally do
        git_log = capture "git log #{revision}..master --pretty=format:'%ad %an %h  %s' --date=short"
        set :git_log, git_log
      end
      execute "echo '#{fetch(:git_log)}' >> #{shared_path}/log/revisions.txt"
    end

    def send_email
      email_content = "Commits in this deployment:<ol>"
      fetch(:git_log).each_line do |line|
        email_content << "<li>#{line}</li>"
      end
      email_content << "</ol>"
      email_content << "You can view the entire history <a href='#{fetch(:redmine_wiki_xml_url).gsub('.xml','')}'>here</a>"
      execute "echo '#{email_content}' | mail -a 'Content-type: text/html;' -s 'Deployment Notifier: #{fetch(:application)} has just been deployed' #{fetch(:revision_email)}"
      execute "echo '#{Time.now.strftime('%d-%m-%Y')}' >> #{shared_path}/log/revisions.txt"
    end

    def create_revisions_history_xml_file
      revisions_xml = File.open("tmp/revisions.xml",'w')
      revisions_xml.truncate(0)
      revisions_xml.write("<?xml version='1.0'?>\n")
      revisions_xml.write("<wiki_page>\n")
      revisions_xml.write("<text>\n")
      capture("cat #{shared_path}/log/revisions.txt").each_line do |line|
        if line.match(/^\d{2}-\d{2}-\d{4}$/)
          revisions_xml.write("h2. #{line} \n\n")
        else
          revisions_xml.write("# #{line} \n")
        end
      end
      revisions_xml.write("</text>\n")
      revisions_xml.write("</wiki_page>")
      revisions_xml.close
      upload! "tmp/revisions.xml", "#{shared_path}/log/revisions.xml"
    end

    def create_redmine_wiki_from_xml_file
        execute "curl -s -H 'Content-Type: application/xml' -X PUT --data-binary '@#{shared_path}/log/revisions.xml' -H 'X-Redmine-API-Key: #{fetch(:redmine_api_key)}' #{fetch(:redmine_wiki_xml_url)}" 
    end
  end
end

