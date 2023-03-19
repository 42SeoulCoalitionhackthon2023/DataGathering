require 'dotenv/load'
require 'mysql2'

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

def update_user_level(user_id, db_client)
	user_id = user_id.to_s
  result = db_client.query("SELECT AVG(final_mark) AS avg_marks FROM feedback WHERE corrector = #{user_id[1..-2]}")
	avg_final_mark = result.first["avg_marks"].to_i
	if(avg_final_mark > 100)
		avg_final_mark = 100
	end
	if(avg_final_mark < 20)
		avg_final_mark = 0
	end
	db_client.query("UPDATE user SET level = #{avg_final_mark} WHERE user_id = #{user_id[1..-2]}")
end

ids = get_user_id(db_client)
total = ids.length
for index in 0..total - 1
	update_user_level(ids[index], db_client)
end
