async = require 'async'
watch = require 'watch'

module.exports = (next) ->
	@on "serve", =>
		return unless @env is 'dev'

		async.each @config.src, (srcPath, startedWatching) =>
			watch.watchTree srcPath, (f, curr, prev) =>
				if typeof f is "object" and prev is null and curr is null
					startedWatching()
				else if prev is null
					@emit "watch:change", "create", f, curr, prev, curr.isDirectory()
				else if curr.nlink is 0
					@emit "watch:change", "delete", f, curr, prev, prev.isDirectory()
				else
					@emit "watch:change", "update", f, curr, prev, curr.isDirectory()
		, (err) =>
			if err then @log "ERROR", "watch failed", err
			else @log "INFO", "watch started"

	@on "watch:change", (eventType, filePath, currStat, prevStat, isDir) =>
		return if isDir or @filterIgnores([filePath]).length is 0

		@log "DEBUG", "watch:change", eventType, filePath

		async.waterfall [
			(cb) =>
				if eventType is 'create'
					@buildFile filePath, cb
				else
					cb null, @queryFile srcFilePath: filePath
			(file, cb) =>
				switch eventType
					when "create"
						reworkFileIds = (f.id for f in @queryFiles extname: file.extname)
						@regenerate reworkFileIds, cb
					when "delete"
						async.series [
							(_cb) => @removeFile file, _cb
							(_cb) =>
								reworkFileIds = (f.id for f in @queryFiles extname: file.extname)
								@regenerate reworkFileIds, _cb
						], cb
					when "update"
						reworkFileIds = [file.id].concat @resolveAllDependants file
						@regenerate reworkFileIds, cb
		], (err) =>
			@log "ERROR", "watch file handling error", err if err

	next()
