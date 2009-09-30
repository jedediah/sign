require "sinatra"
require File.join(File.dirname(__FILE__), "sign.rb")

set :views, File.dirname(__FILE__)

configure do
  read,SIGN_OUT = IO.pipe
  SIGN_THREAD= Thread.new { loop { Sign.new.scroll_text read.readline.chomp } }

  TOKENS = {}
  LONGEST_MESSAGE = 140
end

def generate_token
  token = rand 10**16
  TOKENS[token] = Time.now
  token
end

get "/show" do
  result = catch :sign do
    throw :sign, "no message" unless msg = params[:msg]
    msg.strip!
    msg.gsub!(/[\t\n]+/,' ')
    msg.gsub!(/[^A-Za-z0-9\,\!\?\.\ \@\#\$\%\^\&\*\(\)\-\_\=\+\[\]\{\}\<\>\`\~\"\'\\\:\;\|]/,'?')
    throw :sign, "empty message" if msg.empty?
    throw :sign, "message too long" if msg.size > LONGEST_MESSAGE
    throw :sign, "no token" unless token = params[:token]
    throw :sign, "invalid token" unless token = token.to_i
    throw :sign, "unknown token" unless time = TOKENS[token]
    throw :sign, "expired token" unless time >= Time.now - 60*60

    TOKENS.delete token
    SIGN_OUT.puts msg
    :sent
  end

  if result == :sent
    generate_token.to_s
  else
    halt 400, generate_token.to_s
  end
end

get "/" do
  @token = generate_token
  erb :'web.html'
end
