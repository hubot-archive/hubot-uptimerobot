# Description
#   A hubot script to list/add monitors for the Uptime Robot service.
#
# Configuration:
#   HUBOT_UPTIMEROBOT_APIKEY
#   HUBOT_UPTIMEROBOT_CONTACT_ID (optional)
#
# Commands:
#   hubot uptime <filter> - Returns uptime for sites.
#   hubot uptime add-check <http://example.com> [as <friendlyname>]- Adds a new uptime check.
#
# Author:
#   patcon@myplanetdigital

apiKey = process.env.HUBOT_UPTIMEROBOT_APIKEY
alertContactId = process.env.HUBOT_UPTIMEROBOT_CONTACT_ID

module.exports = (robot) ->

  REGEX = ///
    uptime
    (       # 1)
      \s+   #    whitespace
      (.*)  # 2) filter
    )?
  ///i
  robot.respond REGEX, (msg) ->
    Client = require 'uptime-robot'
    client = new Client apiKey

    filter = msg.match[2]
    data = {}

    client.getMonitors data, (err, res) ->
      if err
        throw err

      monitors = res

      if filter
        query = require 'array-query'
        monitors = query('friendlyname')
          .regex(new RegExp filter, 'i')
          .on res

      for monitor, i in monitors
        name   = monitor.friendlyname
        url    = monitor.url
        uptime = monitor.alltimeuptimeratio
        status = switch monitor.status
          when "0" then "paused"
          when "1" then "not checked yet"
          when "2" then "up"
          when "8" then "seems down"
          when "9" then "down"

        msg.send "#{status.toUpperCase()} <- #{url} (#{uptime}% uptime)"

  robot.respond /uptime add-check (\S+)( as (.*))?$/i, (msg) ->
    url = require('url').parse(msg.match[1])
    friendlyName = msg.match[3] or url.href

    # Check that url format is correct.
    monitorUrl = url.href if url.protocol

    # Create monitor
    msg.http("https://api.uptimerobot.com/newMonitor")
      .query({
        apiKey: apiKey
        monitorFriendlyName: friendlyName
        monitorURL: monitorUrl
        monitorType: 1
        format: "json"
        noJsonCallback: 1
        monitorAlertContacts: [
          alertContactId
        ]
      })
      .get() (err, res, body) ->
        response = JSON.parse(body)

        if response.stat is "ok"
          msg.send "done"

        if response.stat is "fail"
          msg.send "#{response.message}"
