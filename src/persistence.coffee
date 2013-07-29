fs = require 'fs'
logger = require './logger'

class JSONFile
  constructor: (@file_path) ->

  # read and parse json from `@file_path`.
  load: (cb) ->
    fs.exists @file_path, (exists) =>
      unless exists
        return cb? new Error "File does not exist at #{@file_path}"

      fs.readFile @file_path, (error, data) =>
        unless error is null
          return cb? new Error "Could not open file at #{@file_path}"

        try
          cb? null, JSON.parse data
        catch error
          return cb? error
          # return cb? new Error "Could not parse JSON file at #{@file_path}"

  # save an object to `@file_path`.
  save: (data, cb) ->
    logger.debug "JSONFILE.save to #{@file_path} of #{JSON.stringify data} "
    fs.writeFile @file_path, (JSON.stringify data, null, 2), (error) ->
      if error
        cb? error
      else
        cb? null


module.exports =
  JSONFile: JSONFile
