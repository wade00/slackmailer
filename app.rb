require "rubygems"
require "bundler"
require "sinatra"
require "slackbotsy"
require "httparty"
require "json"
require "chronic"
require "dotenv"

Bundler.require
Dotenv.load

campaign_config = {
  client_id:          ENV["CLIENT_ID"],
  client_secret:      ENV["CLIENT_SECRET"],
  slack_team_id:      ENV["SLACK_TEAM_ID"],
  slack_channel_id:   ENV["SLACK_CHANNEL_ID"],
  mailchimp_api_key:  ENV["MAILCHIMP_API_KEY"],
  mailer_template_id: ENV["MAILER_TEMPLATE_ID"],
  slack_channel_name: "links",
  mailchimp_api_url:  "https://us5.api.mailchimp.com/2.0/"
}

bot_config = {
  "incoming_webhook" => ENV["INCOMING_WEBHOOK"],
  "outgoing_token"   => ENV["OUTGOING_TOKEN"]
}

bot = Slackbotsy::Bot.new(bot_config)

get "/" do
  "Hello world! Welcome to the slackmailer app. We let you create and send a new MailChimp campaign from a Slack channel!"
end

post "/new" do
  bot.post({ channel: campaign_config[:slack_channel_name],
             text: "<https://slack.com/oauth/authorize?client_id=#{campaign_config[:client_id]}&team=#{campaign_config[:slack_team_id]}|Click this link to start a new mailer>" })
end

get "/authorize" do
  code       = params[:code]
  auth_url   = "https://slack.com/api/oauth.access?client_id=#{campaign_config[:client_id]}&client_secret=#{campaign_config[:client_secret]}&code=#{code}"
  response   = JSON.parse(HTTParty.get(auth_url).body)
  auth_token = response["access_token"]

  redirect("/campaigns/new?token=#{auth_token}")
end

get "/campaigns/new" do
  @slack_auth_token   = params[:token]
  mailchimp_lists_url = campaign_config[:mailchimp_api_url] + "lists/list.json"
  list_request_body   = { apikey: campaign_config[:mailchimp_api_key] }
  request_headers     = { "Content-Type" => "application/json" }

  response = HTTParty.post(mailchimp_lists_url, body: list_request_body.to_json, headers: request_headers)

  @mailchimp_lists = response["data"]

  erb "setup_campaign.html".to_sym
end

post "/campaigns/links" do
  auth_token = params[:slack_auth_token]
  timeframe  = Chronic.parse(params[:timeframe]).to_i
  hist_url   = "https://slack.com/api/channels.history?token=#{auth_token}&channel=#{campaign_config[:slack_channel_id]}&oldest=#{timeframe}"
  response   = JSON.parse(HTTParty.get(hist_url).body)
  @links     = []
  @mailchimp_list = params[:mailchimp_list]

  if response["messages"].nil?
    erb "no_links.html".to_sym
  else
    @links = response["messages"].each_with_index.map do |message, index|
      if message.include?("attachments")
        attachments = message["attachments"][0]
        if attachments.has_key?("title_link")
          { id: index,
            title: attachments["title"].nil? ? attachments["from_url"] : attachments["title"],
            url: attachments["title_link"],
            preview: attachments["text"].nil? ? attachments["fallback"] : attachments["text"][0..400] }
        end
      elsif message["text"].include?("<http") && message["subtype"].nil?
        url = "http" + message["text"].split("http")[1].split(">")[0]
        { id: index, title: url, url: url, preview: "Unable to generate preview" }
      else
        nil
      end
    end.compact!

    erb "new_campaign.html".to_sym
  end
end

post "/campaigns/send" do
  @mailchimp_list = params[:mailchimp_list]
  links_html     = ""

  @included_links = params.map do |key, value|
    if value.include?("|||")
      values = value.split("|||")
      { title: values[0], url: values[1], preview: values[2] }
    else
      nil
    end
  end.compact!

  @included_links.each do |link|
    links_html += "<tr><td><p><a href='#{link[:url]}'>#{link[:title]}</a><br />#{link[:preview]}</p></td></tr>"
    links_html
  end

  send_mailchimp_campaign(content: links_html, config: campaign_config, list: @mailchimp_list)

  erb "send_campaign_confirmation.html".to_sym
end

private

  def send_mailchimp_campaign(args)
    campaign_config   = args[:config]
    mailer_list       = args[:list]
    new_campaign_url  = campaign_config[:mailchimp_api_url] + "campaigns/create.json"
    send_campaign_url = campaign_config[:mailchimp_api_url] + "campaigns/send.json"
    request_headers   = { "Content-Type" => "application/json" }

    new_campaign_options = { list_id: mailer_list,
                             subject: "LPL Weekly",
                             from_email: "contact@launchpadlab.com",
                             from_name: "LaunchPad Lab",
                             to_name: "LaunchPad Friends",
                             template_id: campaign_config[:mailer_template_id] }
    new_campaign_content = { sections: { links: args[:content] } }
    new_campaign_request = { apikey: campaign_config[:mailchimp_api_key],
                             type: "regular",
                             options: new_campaign_options,
                             content: new_campaign_content }

    campaign = HTTParty.post(new_campaign_url, body: new_campaign_request.to_json, headers: request_headers)

    HTTParty.post(send_campaign_url, body: { apikey: campaign_config[:mailchimp_api_key], cid: campaign["id"] }.to_json, headers: request_headers)
  end
