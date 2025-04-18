local webhook = {
	url = "",
	username = "0ne Hub",
}

function webhook.send(content, embeds)
	local success, result = pcall(function()
		if webhook.url == "" then
			print("Webhook URL is empty")
			return false
		end

		local data = {
			content = content,
			username = webhook.username,
			embeds = embeds,
		}

		local requestFunc
		if syn and syn.request then
			requestFunc = syn.request
		elseif http and http.request then
			requestFunc = http.request
		elseif request then
			requestFunc = request
		elseif http_request then
			requestFunc = http_request
		end

		if not requestFunc then
			print("No HTTP request function found")
			return false
		end

		local jsonData
		local jsonSuccess, jsonResult = pcall(function()
			return HttpService:JSONEncode(data)
		end)

		if not jsonSuccess then
			print("JSON encode failed:", jsonResult)
			return false
		end

		jsonData = jsonResult
		if not jsonData then
			print("JSON data is nil after encoding")
			return false
		end

		print("Sending webhook with data length:", #jsonData)

		local reqSuccess, response = pcall(function()
			return requestFunc({
				Url = webhook.url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = jsonData,
			})
		end)

		if not reqSuccess then
			print("Request failed:", response)
			return false
		end

		print("Webhook response status:", response.StatusCode)

		if response.StatusCode ~= 204 and response.StatusCode ~= 200 then
			print("Webhook request failed with status:", response.StatusCode)
			print("Response body:", response.Body)
			return false
		end

		return true
	end)

	if not success then
		print("Webhook error:", result)
	end

	return success and result
end

return webhook
