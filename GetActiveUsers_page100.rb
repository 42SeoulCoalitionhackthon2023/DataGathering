require "oauth2"
require "date"
require 'dotenv/load'

UID = ENV.fetch('UID')
SECRET = ENV.fetch('SECRET')
client = OAuth2::Client.new(UID, SECRET, site: "https://api.intra.42.fr")
token = client.client_credentials.get_token

# 데이터 가져오는 로직
def get_data(token)
  data = []
  x = 1
  loop do
    response = token.get("/v2/cursus_users?filter[campus_id]=29&page[size]=100&page[number]=#{x}").parsed
    break if response.empty?
    data << response
    x += 1
    sleep 0.1
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

result = get_data(token)
# puts result
print_data(result)
