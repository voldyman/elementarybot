require 'cinch'
require 'open-uri'
require 'nokogiri'
require 'cgi'
require 'json'
require 'net/http'
require "./MemoPlugin"

class Memo < Struct.new(:nick, :channel, :text, :time)
  def to_s
    "[#{time.asctime}] <#{channel}/#{nick}> #{text}"
  end
end

class Seen < Struct.new(:who, :where, :what, :time)
  def to_s
    "[#{time.asctime}] #{who} was seen in #{where} saying '#{what}'"
  end
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "chat.freenode.net"
    c.nick     = "IndBot"
    c.channels = ["##rindia", "#rindia"]
    @@users = {}
    @@memos = Memos.new
  end

  helpers do
    def urban_dict(query)
      url = "http://www.urbandictionary.com/define.php?term=#{CGI.escape(query)}"
      CGI.unescape_html Nokogiri::HTML(open(url)).at("div.definition").text.gsub(/\s+/, ' ') rescue nil
    end

    def chuck()
      resp = Net::HTTP.get_response(URI.parse("http://api.icndb.com/jokes/random/"))
      data = resp.body
      result = JSON.parse(data)
      if result.has_key? 'Error'
         raise "web service error"
      end
      return result["value"]["joke"]
    end

    def weatherf(query)
      url = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(query)}"
      resp = Net::HTTP.get_response(URI.parse(url))
      result = JSON.parse(resp.body)
      if result.has_key? "weather"
        return "#{result['weather'][0]['description']} and the Temperatur is #{result['main']['temp']} Fahrenheit"
      end
    end

    def weatherc(query)
      url = "http://api.openweathermap.org/data/2.5/weather?q=#{CGI.escape(query)}&units=metric"
      resp = Net::HTTP.get_response(URI.parse(url))
      result = JSON.parse(resp.body)
      if result.has_key? "weather"
        return "#{result['weather'][0]['description']} and the Temperatur is #{result['main']['temp']} Celsius"
      end
    end

    def advice(query)
      url = "http://api.adviceslip.com/advice/search/#{CGI.escape(query)}"
      resp = Net::HTTP.get_response(URI.parse(url))
      data = resp.body
      result = JSON.parse(data)
      if result.has_key? "slips"
        advice = result['slips'][0]['advice']
        return "#{advice}"
      else
        return 'I found nothing on that Topic'
      end
    end

    def randomadvice()
      url = "http://api.adviceslip.com/advice"
      resp = Net::HTTP.get_response(URI.parse(url))
      data = resp.body
      result = JSON.parse(data)
      return result['slip']['advice']
    end

    def information()
        text = "Welcome to the /r/India's channel. This place is for full timepass. "
        text
    end
  end

  on :join do |m|
    if m.channel == "##rindia"
        #inform users
        m.user.notice(information())
    end

    memos = @@memos.get_memo(m.user.nick)
    if memos
      memos.each do |memo|
        m.user.send memo
      end
    end
  end

  on :channel do |m|
      @@users[m.user.nick] = Seen.new(m.user.nick, m.channel, m.message, Time.new)
  end

  on :channel, /^!seen (.+)/ do |m, nick|
      if nick == bot.nick
        m.reply "That's me!"
      elsif nick == m.user.nick
        m.reply "That's you!"
      elsif @@users.key?(nick)
        m.reply @@users[nick].to_s
      else
        m.reply "I haven't seen #{nick}"
      end
  end

  on :message, /^!memo (.+?) (.+)/ do |m, nick, message|
    if nick == bot.nick
      m.reply "Thanks, but no thanks!"
      return
    elsif m.user.nick == nick
      m.reply "Stop talking to yourself"
      return
    else
      @@memos.add_memo(m.user.nick,nick, message, Time.now, m.channel.to_s)
      m.reply "Added memo for #{nick}"
    end
  end

  on :message, /^!urban (.+)/ do |m, term|
    m.reply(urban_dict(term) || "No results found", true)
  end

  on :message, /^!chuck/ do |m, term|
    m.reply chuck()
  end

  on :message, /^!google (.+)/ do |m, query|
    m.reply "Search for solutions: 'http://www.google.com/search?q=#{query}'"
  end

  on :message, /^!lp (.+)/ do |m,query|
    m.reply "https://launchpad.net/#{query}"
  end

  on :message, /^!bug (.+)/ do |m,query|
   m.reply " https://bugs.launchpad.net/bugs/#{query}"
  end

  on :message, /^!gtk (.+)/ do |m,query|
   m.reply " http://www.valadoc.org/#!api=gtk+-3.0/Gtk.#{query}"
  end

  on :message, /^!github (.+?) (.+)/ do |m, author, project|
   m.reply " https://www.github.com/#{author}/#{project}"
  end

  on :message, /^!weatherf (.+)/ do |m, query|
    m.reply "#{m.user.nick}: " + weatherf(query)
  end

  on :message, /^!weatherc (.+)/ do |m, query|
    m.reply "#{m.user.nick}: " + weatherc(query)
  end

  on :message, /^!advice (.+)/ do |m, query|
    m.reply "#{m.user.nick}: " + advice(query)
  end

  on :message, /^!randomadvice/ do |m|
    m.reply "#{m.user.nick}: " + randomadvice
  end

  on :message, /^!help/ do |m, query|
    m.reply "#{m.user.nick}: I know these Commands: !google <searchterm>, !ot <name>, !web <name>, !askm <name>, !seen <nick>, !hello, !memo <nick> <message>, !chuck, !love <nick>, !randomadvice, !advice <term>, !weatherc <city,land>, !weatherf <city,land>, !telloff <nick>, "
  end

  on :message, /^!hello/ do |m, query|
    m.reply "#{m.user.nick} hey how are you?"
  end

  on :message, /^!love (.+)/ do |m, nick|
    m.reply "#{nick}: You got a thousand kisses from #{m.user.nick} "
  end

  on :message, /^!ot (.+)/ do |m, nick|
    if nick == bot.nick
       m.reply "#{nick}: That's me!"
    else
       m.reply "#{nick}: You are talking about offtopic stuff! Please join #elementary-offtopic"
    end
  end

  on :message, /^!nick (.+)/ do |m, nick|
    if nick == bot.nick
       m.reply "#{nick}: That's me!"
    else
       m.reply "#{nick}: If you want to change your irc-nick, please use '/nick <yournick>'"
    end
  end

  on :message, /^!telloff (.+)/ do |m, nick|
    if nick == bot.nick
      m.reply "#{nick}: How dare you?!?"
    else
      m.reply "#{nick}: You are being annoying. Accept this bribery and shut up."
    end
  end
end

bot.start
