$:.unshift(File.join(File.dirname(__FILE__)))
require 'oauth/oauth'
require 'oauth/oauth/oauth'
require 'oauth/client/helper'
require 'oauth/signature/hmac/sha1'
require 'oauth/request_proxy/mock_request'
require 'oauth/test/consumer'
