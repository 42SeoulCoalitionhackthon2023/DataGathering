require "oauth2"
require "date"
require 'dotenv/load'
require 'mysql2'

UID = ENV.fetch('UID')
SECRET = ENV.fetch('SECRET')
api_client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = api_client.client_credentials.get_token

# 데이터 가져오는 로직
def get_data(token)
  data = []
  x = 0
  loop do
    response = token.get("/v2/cursus_users?filter[campus_id]=29&page[size]=100&page[number]=#{x}").parsed
    break if response.empty?
    data << response
    x += 1
    sleep 0.1
    # puts x
  rescue => e
    puts "Error occurred: #{e.message}"
    puts "Retrying in 5 seconds..."
    sleep 5
  end

  return data.flat_map(&:itself)
end

# 출력 로직
# 그냥 데이터를 받아오면, 피신 데이터도 들고오기 때문에 바꿔야된다. 
def print_data(data)
  today = Date.today
	data.each do |element|
		if (!(element["blackholed_at"].nil?) && element["grade"] != "Member")
			date = Date.parse(element["blackholed_at"])
			if element["grade"] != "Member" && date < today
				next
			end
		end
		if element["grade"].nil?
			next
		end
    puts element.fetch("level")
    puts element.fetch("blackholed_at")
    puts element.dig("user", "id")
    puts element.dig("user", "login")
    puts element.dig("user", "image", "versions", "small")
    puts "\n"
  end
end

def put_database(data)
  db_client = Mysql2::Client.new(
    host: ENV.fetch('ENV_HOST'),
    username: ENV.fetch('ENV_USERNAME'),
    password: ENV.fetch('ENV_PASSWORD'),
    database: ENV.fetch('ENV_DATABASE')
  )
  today = Date.today
	data.each do |element|
		if (!(element["blackholed_at"].nil?) && element["grade"] != "Member")
			date = Date.parse(element["blackholed_at"])
			if element["grade"] != "Member" && date < today
				next
			end
		end
		if element["grade"].nil?
			next
		end
    level = element.fetch("level")
    
    temp = element.fetch("blackholed_at")
    blackhole = nil
    unless temp.nil?
      blackhole = DateTime.iso8601(temp).strftime('%Y-%m-%d %H:%M:%S')
    end

    user_id = element.dig("user", "id")
    intra_id = element.dig("user", "login")
    
    image = nil
    unless element.dig("user", "image", "versions", "small").nil?
      image = element.dig("user", "image", "versions", "small")
    end
    existing_user = db_client.query("SELECT * FROM user WHERE user_id = #{user_id}").first
    if existing_user
      # puts "update"
      update_statement = db_client.prepare("UPDATE user SET intra_id = ?, image = ?, blackhole = ? WHERE user_id = ?")
      update_statement.execute(intra_id, image, blackhole, user_id)
    else
      # puts "insert"
      statement = db_client.prepare("INSERT INTO user(user_id, intra_id, image, blackhole, level) VALUES (?, ?, ?, ?, ?)")
      statement.execute(user_id, intra_id, image, blackhole, level)
    end
  end
end

result = get_data(token)
# puts result
# print_data(result)
put_database(result)
