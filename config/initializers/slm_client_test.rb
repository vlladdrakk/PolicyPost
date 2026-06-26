if Rails.env.test?
  ENV["SLM_TIMEOUT"] = "1"
  ENV["SLM_BASE_URL"] = "http://localhost:19999/v1"
  ENV["SLM_API_KEY"] = "test"
end
