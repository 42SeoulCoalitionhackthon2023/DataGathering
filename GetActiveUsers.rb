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
    response = token.get("/v2/cursus_users?filter[campus_id]=29&page[number]=#{x}").parsed
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
def print_data(data)
  today = Date.today
  data.each do |element|
    unless element.fetch("blackholed_at") && element.fetch("grade") != "Member"
      next
    end
    next unless element.fetch("user", nil)
    date = Date.parse(element.fetch("blackholed_at"))
    if element.fetch("grade") != "Member" && date < today
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
print_data(result)
