require "active_record"
require "will_paginate"
require "autoscope/active_record_methods"
require "autoscope/version"

module Autoscope
  # Your code goes here...
end

::ActiveRecord::Base.send(:include, Autoscope::ActiveRecordMethods)
