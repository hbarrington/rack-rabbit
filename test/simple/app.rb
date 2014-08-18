class SimpleApp

  def self.call(env)

    method = env["REQUEST_METHOD"]
    path   = env["PATH_INFO"]
    query  = env["QUERY_STRING"]
    body   = env["rack.input"].read
    logger = env["rack.logger"]

    duration = path.to_s.split("/").last.to_i

    response = []
    response << "Method: #{method}"
    response << "Path: #{path}"
    response << "Query: #{query}" unless query.nil? || query.empty?
    response << "Duration: #{duration}"
    response << body

    duration.times do |n|
      logger.info "sleeper #{n}"
      sleep 1
    end

    env["rabbit.message"].ack if path.include?("ackit")
    env["rabbit.message"].reject if path.include?("rejectit")

    raise "wtf" if path.include?("error")

    [ 200, {}, [ response.join("\n") ] ]

  end

end
