# rp5

load_library "opengl"

def setup
  #size(200, 200, OPENGL)
  size(screenWidth, screenHeight, OPENGL)
  hint ENABLE_OPENGL_4X_SMOOTH
end

def draw
  background(255)
  #p frame_rate
  lights()
  translate(width/2, height/2)

  rotateY(frameCount/10.0)
  rotateZ(frameCount/50.0)
  box(width*0.375)
=begin
  count = 3000.0
  s = 50
  count.to_i.times do |i|
    translate(i * width/count, i * width/count)
    box(5)
  end
=end
  #line(0, 0, width, height)
end
