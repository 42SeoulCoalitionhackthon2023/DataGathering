require "oauth2"
require "date"
require 'dotenv/load'
require 'mysql2'

UID = ENV.fetch('UID')
SECRET = ENV.fetch('SECRET')
api_client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = api_client.client_credentials.get_token

db_client = Mysql2::Client.new(
	host: ENV.fetch('ENV_HOST'),
	username: ENV.fetch('ENV_USERNAME'),
	password: ENV.fetch('ENV_PASSWORD'),
	database: ENV.fetch('ENV_DATABASE')
)

def get_user_id(db_client)
	statement2 = db_client.prepare("SELECT user_id FROM user")
	result = statement2.execute();
	rows = result.to_a.map(&:values)
	return rows
end

def get_feedbacks(ids, token, db_client)
	length = ids.length
  failed = []
  for index in 0..length-1
    begin
      id = (ids[index].to_s)
      result = token.get("/v2/users/#{id[1..-2]}/scale_teams/as_corrector?page[size]=100").parsed
      unless result.nil?
        insert_feedback(db_client, result)
      end
      sleep 0.1
    rescue => exception
      puts "Error occurred: #{exception.message}"
      failed.push(index)
    end
    index += 1
  end
end

def insert_feedback(db_client, result)
total = result.length
correction_id, comment, feedback, final_mark, flag_outstanding, corrector, corrected, created_at, project_id, project_name = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
# 초기화 완료
for index in 0..total-1
  # puts result[index].fetch("id")
  # puts result[index]
  check_qurey = db_client.prepare("SELECT CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END AS `exists` FROM feedback WHERE correction_id = #{result[index].fetch("id")}")
  if (result[index].fetch("id").nil?) || (check_qurey.execute().first['exists'] != 0)
    next
  else
    correction_id = (result[index]).fetch("id")
  end
  unless result[index].fetch("comment").nil?
    comment = result[index].fetch("comment")
    # comment = comment_str.encode('ASCII', 'UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
  unless result[index].fetch("created_at").nil?
    created_at = DateTime.iso8601(result[index].fetch("created_at")).strftime('%Y-%m-%d %H:%M:%S')
  end
  unless result[index].fetch("feedback").nil?
    feedback = result[index].fetch("feedback")
    # feedback = feedback_str.encode('ASCII', 'UTF-8', invalid: :replace, undef: :replace, replace: '')
  end
  if result[index].fetch("final_mark").nil?
    next
  end
  final_mark = result[index].fetch("final_mark")
  unless result[index].dig("flag", "name").nil?
    if result[index].dig("flag", "name") == "Outstanding project"
      flag_outstanding = true
    else
      flag_outstanding = false
    end
  end
  unless result[index]["correcteds"][0]["id"].nil?
    corrected = result[index]["correcteds"][0]["id"]
  end
  unless result[index]["corrector"]["id"].nil?
    corrector = result[index]["corrector"]["id"]
  end
  unless result[index]["team"]["project_id"].nil?
    project_id = result[index]["team"]["project_id"]
  end
  unless result[index]["team"]["project_gitlab_path"].split("/").last.nil?
    project_name = result[index]["team"]["project_gitlab_path"].split("/").last
  end
  # puts correction_id, comment, feedback, final_mark, flag_outstanding, corrector, corrected, created_at, project_id, project_name
  # puts "#{index} \n\n"
  # puts feedback_str, comment_str
  statement = db_client.prepare("INSERT INTO feedback(correction_id, comment, feedback, final_mark, flag_outstanding, corrector, corrected, created_at, project_id, project_name) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)")
  statement.execute(correction_id, comment.gsub(/\p{Emoji}/, ''), feedback.gsub(/\p{Emoji}/, ''), final_mark, flag_outstanding, corrector, corrected, created_at, project_id, project_name)
end

end



result = get_user_id(db_client)
get_feedbacks(result, token, db_client)
