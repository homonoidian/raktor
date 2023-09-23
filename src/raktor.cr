require "log"
require "json"
require "uuid"
require "http"
require "cannon"
require "immutable"

require "./ext/*"
require "./raktor/term"
require "./raktor/protocol"
require "./raktor/sparse"
require "./raktor/format"
require "./raktor/node"
require "./raktor/recipe"

# TODO: Write documentation for `Raktor`
module Raktor
  VERSION = "0.1.0"
end

Log.setup(:trace)
