module CaptureSupport
  def capture(stream)
    begin
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end
end

RSpec.configure do |config|
  config.include CaptureSupport
end
