#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'loop'

# Flush output immediately
$stdout.sync = true

Loop.start