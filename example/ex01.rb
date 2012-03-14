require 'pp'
# require 'require_faster'

require 'other'
require 'other.rb'
require File.expand_path('other')
require 'other'

$:.unshift "some/other/path"
require 'other'

pp [ :'$: = ', $: ]
pp [ :'$" = ', $" ]

require 'some_file_that_doesnt_exist' rescue nil
require 'some_file_that_doesnt_exist' rescue nil
