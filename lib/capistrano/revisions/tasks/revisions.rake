namespace :deploy do

  desc <<-DESC
    Creates a Redmine Wiki page which displays the commits since your last deploy.
  DESC
  task :revisions => "deploy:revisions:create"

  namespace :revisions do
    task :create do
      on roles(:web) do |host|
        revision = capture "cat #{current_path}/REVISION"
        run_locally do
          git_log = capture "git log #{revision}..master --pretty=format:'%ad %an %h  %s' --date=short"
          set :git_log, git_log
        end
        execute "echo #{fetch(:git_log)} >> #{current_path}/revisions.txt"
        xml = "<?xml version='1.0'?><wiki_page><text>"
        capture("cat #{current_path}/revisions.txt").each_line do |line|
          xml << '&#xA; # '
          xml << line
        end
        xml << "</text></wiki_page>"
        execute "echo \"#{xml}\" > #{current_path}/revisions.xml"
        execute "curl -v -H 'Content-Type: application/xml' -X PUT --data-binary '@#{current_path}/revisions.xml' -H 'X-Redmine-API-Key: #{fetch(:redmine_api_key)}' #{fetch(:redmine_wiki_xml_url)}" 
      end
    end
  end
end
