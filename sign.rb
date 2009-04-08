require 'socket'
require 'RMagick'

class Array
  def to_ascii
    reduce("".encode("ASCII-8BIT")) {|s,n| s << n.chr}
  end
end

class Sign
  WIDTH = 96
  HEIGHT = 32
  HEADER = [0x23,0x54,0x26,0x66,
            0,32,    # height
            0,96,    # width
            0,1,     # channels
            0,0xff]  # max pixel value

  def initialize ip="192.168.111.4", port=2330
    @sock = UDPSocket.new
    @sock.connect ip,port
    @img = Magick::Image.new(WIDTH, HEIGHT) do
      self.image_type = Magick::BilevelType
      self.background_color = "black"
    end
  end

  def show pix=nil
    if pix.nil?
      show @img.export_pixels(0,0,WIDTH,HEIGHT,"I").map{|n| n > 0x7fff ? 0xff : 1 }
    elsif pix.is_a? Array
      @sock.send (HEADER+pix).to_ascii,0
    end
  end

  def show_file fn
    a = []
    y = 0

    File.readlines(fn).each do |line|
      if y < HEIGHT && line !~ /^#/
        a += (0...WIDTH).map{|x| if line.size <= x || line[x] == " " then 1 else 0xff end }
        y += 1
      end
    end

    a += [1]*(WIDTH*(HEIGHT-y).abs)
    show a
  end

  def draw_text x, y, height, text, options={}
    d = Magick::Draw.new
    d.fill = if !options.has_key? :color || options[:color] then "white" else "black" end
    d.font = options[:font] || "impact.ttf"
    d.font_weight = options[:weight] || Magick::NormalWeight

    d.pointsize = 100
    d.pointsize = 100.0 / (d.get_type_metrics(@img,text).height.to_f / height)
    mets = d.get_type_metrics(@img,text)

    ref = [x,y]
    dim = [mets.width,mets.height]
    p = [0,1].map do |i|
      case options[:align] && options[:align][i] || [:top,:left]
        when :top,:left then ref[i]
        when :bottom,:right then ref[i]-dim[i]
        when :center then ref[i]-dim[i]/2
      end
    end
    p[1] += mets.descent + mets.height
    d.annotate(@img,WIDTH,HEIGHT,p[0],p[1],text)
  end

  def draw_clear
    d = Magick::Draw.new
    d.fill = "black"
    d.rectangle(0,0,WIDTH-1,HEIGHT-1)
    d.draw(@img)
  end

  def text_width height, text, options={}
    d = Magick::Draw.new
    d.font = options[:font] || "impact.ttf"
    d.font_weight = options[:weight] || Magick::NormalWeight

    d.pointsize = 100
    d.pointsize = 100.0 / (d.get_type_metrics(@img,text).height.to_f / height)
    d.get_type_metrics(@img,text).width
  end

  def scroll_text msg
    step = 1
    ((text_width(HEIGHT, msg) + WIDTH)/step + 2).to_i.times do |i|
      draw_clear
      draw_text WIDTH-i*step, HEIGHT/2, HEIGHT, msg, :align => [:left, :center]
      show
      sleep 0.03
    end
  end

  def show_text msg
    draw_text WIDTH/2, HEIGHT/2, HEIGHT, msg, :align => [:center,:center]
    show
  end

  def clear
    show [1]*(WIDTH*HEIGHT)
  end

  def close
    @socket.close
  end
end
