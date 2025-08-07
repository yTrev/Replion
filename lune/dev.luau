local process = require('@lune/process')
local task = require('@lune/task')

task.spawn(function()
	process.exec('rojo', { 'sourcemap', '--watch', 'test.project.json', '-o', 'sourcemap.json' }, { stdio = 'forward' })
end)

task.spawn(function()
	process.exec('rojo', { 'serve', 'test.project.json' }, { stdio = 'forward' })
end)
