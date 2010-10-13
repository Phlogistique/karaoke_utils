##continuous.rb
## 
## Copyright (C) 2010 Noé Rubinstein <noe.rubinstein@gmail.com>
## This program is free software; you can redistribute it and/or modify
## it under the terms of the GNU General Public License as published by
## the Free Software Foundation; either version 2 of the License, or
## (at your option) any later version.
## 
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU General Public License for more details.
## 
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
##

module ToyundaGen
  module Styles

    private
    module ProgressiveCursor
      def output_cursor(writer, line)
        
        assert((not line.row.nil?), "@row is nil")

        return unless line.has_frames?

        #lol I have no idea about the correct way to do that
        subsize = line.length > 40 ? 30 * 40.0 / line.length : 30

        writer.pipe_count = line.row + 1
        center_on_syllable = line.vars.center_on_syllable
        line.vars.center_on_syllable = false # progressive cursor should always start at beginning

        start_x = ToyundaLib::Conversion::str_to_x(line.to_s, subsize)
        char_width = ToyundaLib::Conversion::char_width(subsize)
        line.syls.length.times do |i|
          syl = line.syls[i]
          end_x = start_x + char_width * syl.to_s.length
	  if syl.has_frames?
            writer.add(syl.frames, line.size_string, "{o:%d,0:%d,0}" % [start_x.round, end_x.round], ToyundaLib::ToyundaPlayer::CursorChar)
	  end
          start_x = end_x
        end
        line.vars.center_on_syllable = center_on_syllable
        writer.pipe_count = line.row
      end
    end

    module SupportedStyles

      class Continuous < Style

        include ProgressiveCursor

        def init(vars)
          vars.declare("transition_min_frame", Types::Int.new(3, "Number of frames under which the color of a letter will change immediatly instead of fade. Set to a higher value for a smaller file if the song is fast (continuous mode 0 only)"))
          vars.declare("cont_mode", Types::Int.new(0, "mode for continuous style: 0 = simple fade, 1 = virtually 1-char wide highlight, 2 = virtually 2-char wide highlight"))
          vars.declare("fade", Types::Bool.new(true, "Fade the line in and out (continuous only)"))
        end

        def line_times(n)
          if n < 0
            r = @line_times[0]
          elsif n > @line_times.length - 1
            r = @line_times[-1]
          else
            up = n.ceil
            down = n.floor
            proportion = n - down

            if up == down
              r = @line_times[n]
            else
              r = @line_times[down] + proportion * (@line_times[up] - @line_times[down])
            end
          end

          r.round
        end

        def process_line(writer, line)
          @line_times = []
        end

        def process_syl(writer, line, j)
          if (not line.syls[j].nil?) and line.syls[j].has_frames?
            syl = line.syls[j]

            syl_start, syl_stop = syl.frames
            nbchar = syl.length
            char_len = (syl_stop - syl_start) / nbchar.to_f
            
            nbchar.times do |i|
              start = syl_start + i * char_len
              stop = start + char_len

              @line_times << start if @line_times.empty?
              @line_times << stop
            end
          end
        end

        def process_char(writer, line, i)

          str = line.only_char(i)
          
          if line.vars.fade
            writer.add([line.start - line.vars.fade_before, line.start], line.colors[0].fade_in, str)
            writer.add([line.stop, line.stop + line.vars.fade_after], line.colors[2].fade_out, str)
          end

          life = colors = nil # declaration
          case line.vars.cont_mode
          when 0
            if line_times(i + 1) - line_times(i) < line.vars.transition_min_frame
              life = [
                line.start,
                line_times(i + 0.5),
                line.stop
              ]
              colors = [
                ToyundaLib::ToyundaColor.new(line.vars.color_before), 
                ToyundaLib::ToyundaColor.new(line.vars.color_after), 
              ]
            else
              life = [
                line.start,
                line_times(i),
                line_times(i + 1),
                line.stop
              ]
              colors = [
                ToyundaLib::ToyundaColor.new(line.vars.color_before), 
                ToyundaLib::ToyundaColor.new(line.vars.color_before, line.vars.color_after), 
                ToyundaLib::ToyundaColor.new(line.vars.color_after), 
              ]
            end
          when 1
            life = [
              line.start,
              line_times(i - 0.5),
              line_times(i + 0.5),
              line_times(i + 1.5),
              line.stop,
            ]
            colors = [
              ToyundaLib::ToyundaColor.new(line.vars.color_before), 
              ToyundaLib::ToyundaColor.new(line.vars.color_before, line.vars.color_current), 
              ToyundaLib::ToyundaColor.new(line.vars.color_current, line.vars.color_after), 
              ToyundaLib::ToyundaColor.new(line.vars.color_after), 
            ]
          when 2
            life = [
              line.start,
              line_times(i - 1),
              line_times(i),
              line_times(i + 1),
              line_times(i + 2),
              line.stop
            ]
            colors = [
              ToyundaLib::ToyundaColor.new(line.vars.color_before), 
              ToyundaLib::ToyundaColor.new(line.vars.color_before, line.vars.color_current), 
              ToyundaLib::ToyundaColor.new(line.vars.color_current), 
              ToyundaLib::ToyundaColor.new(line.vars.color_current, line.vars.color_after), 
              ToyundaLib::ToyundaColor.new(line.vars.color_after), 
            ]
          else
            $stderr.puts "Unsupported mode, exiting"
            exit 1
          end
          colors.each_index do |i|
            writer.add(life[i .. i+1], colors[i], str) if life[i] < life[i+1]
          end
        end
      end
    end
  end
end

# vim: shiftwidth=2:expandtab
