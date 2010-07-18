
require 'shellwords'
require 'pathname'

$raw_flags = %W[-Wfatal-errors -Wformat-nonliteral -Wformat-security -Wall -Wextra -Wshadow -Wunsafe-loop-optimizations -Wpointer-arith -Wbad-function-cast -Wcast-qual -Wcast-align -Wwrite-strings -Wshorten-64-to-32 -Waggregate-return -Wstrict-prototypes -Wold-style-definition -Wmissing-prototypes -Wmissing-declarations -Wmissing-noreturn -Wpadded -Winline -Wstrict-aliasing -Wdisabled-optimization -Winvalid-pch -Wnewline-eof -fvisibility=hidden -mno-red-zone -feliminate-unused-debug-types -fmessage-length=0 -pipe -freorder-blocks -ftree-vectorize -fno-pic -mdynamic-no-pic -std=gnu99 -gdwarf-2 -Os -mtune=core2 -msse -msse2 -msse3 -mfpmath=sse -fdiagnostics-show-option]

class Object
  def to_arg
    self.to_s.shellescape
  end
end
class Array
  def to_args
    self.map{ |x| x.to_arg }.join(' ')
  end
end

class Target

  def initialize(name)
    @name = name
    @sources = Pathname.glob(name+'.[cm]')
    @cflags = []

    @build_dir = Pathname.new('../build')
    @bin_dir = @build_dir + 'bin'
  end

  def warn(*list)
    list.each { |x| @cflags << ('-W' + x) }
  end

  def frameworks(*list)
    list.each { |x| @cflags << '-framework' << x }
  end

  def build
    cmd = 'gcc -o ' + (@bin_dir + @name).to_arg + ' ' + $raw_flags.join(' ') + ' ' + @cflags.to_args +
      ' -DUTIL_NAME=\"' + @name.to_arg + '\" ' + @sources.to_args
    puts '==> Building ' + @name
    if not system cmd
      puts ' ** Build Failed **'
      exit 1
    end
  end
end

targets={}
%w(alert app setapp appr dux trash).each { |x|
  targets[x] = Target.new(x)
}
%w(alert app setapp appr trash).each { |x|
  targets[x].frameworks 'AppKit'
}
# these use CoreFoundation and Foundation
%w(alert app setapp appr).each { |x|
  targets[x].warn 'no-cast-qual'
}
%(appr).each { |x|
  targets[x].warn 'no-format-nonliteral'
}
%w(dux).each { |x|
  targets[x].frameworks 'CoreServices'
}

if ARGV.length > 0
  ARGV.each { |x| targets[x].build }
else
  targets.each_value { |target| target.build }
end

