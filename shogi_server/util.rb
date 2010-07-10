## $Id$

## Copyright (C) 2004 NABEYA Kenichi (aka nanami@2ch)
## Copyright (C) 2007-2008 Daigo Moriwaki (daigo at debian dot org)
##
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
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

require 'date'
require 'fileutils'
require 'pathname'

module ShogiServer

  # Generate a random number such as i<=n<max
  def random(i, max)
    return i if i >= max
    return rand(max-i)+i
  end
  module_function :random

  def shuffle(array)
    return if array.size < 2
    for i in 0...(array.size-1)
      r = random(i, array.size)
      a = array[i]
      array[i] = array[r]
      array[r] = a
    end
  end
  module_function :shuffle

  # See if the file is writable. The file will be created if it does not exist
  # yet.
  # Return true if the file is writable, otherwise false.
  #
  def is_writable_file?(file)
    if String === file
      file = Pathname.new file
    end
    if file.exist?
      if file.file?
        return file.writable_real?
      else
        return false
      end
    end
    
    begin
      file.open("w") {|fh| } 
      file.delete
    rescue
      return false
    end

    return true
  end
  module_function :is_writable_file?

  # Convert a DateTime insntace to a Time instance.
  #
  def datetime2time(dt)
    return Time.mktime dt.year, dt.month, dt.day, dt.hour, dt.min, dt.sec
  end
  module_function :datetime2time

  # Convert a Time instance to a DateTime instance
  #
  def time2datetime(time)
    return DateTime.new(time.year, time.mon, time.mday,
                        time.hour, time.min, time.sec)
  end
  module_function :time2datetime

  # Parse string representing a day-of-week and return a coresponding
  # integer value: 1 (Monday) - 7 (Sunday)
  #
  def parse_dow(str)
    index = Date::DAYNAMES.index(str) || Date::ABBR_DAYNAMES.index(str)
    return nil if index.nil?
    return index == 0 ? 7 : index
  end
  module_function :parse_dow
end
